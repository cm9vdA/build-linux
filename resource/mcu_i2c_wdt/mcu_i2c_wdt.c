// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/i2c.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/slab.h>
#include <linux/delay.h>
#include <linux/workqueue.h>
#include <linux/mutex.h>
#include <linux/version.h>

#define MCU_WDT_MAX_PACKET      64
#define MCU_WDT_MIN_INTERVAL    1
#define MCU_WDT_MAX_INTERVAL    300

// 调试开关，开启打印详细流程日志
#define MCU_WDT_DEBUG          1
#if MCU_WDT_DEBUG
#define mcu_dbg(dev, fmt, ...) dev_dbg(dev, "[mcu_wdt] " fmt, ##__VA_ARGS__)
#else
#define mcu_dbg(dev, fmt, ...) do {} while (0)
#endif
#define mcu_info(dev, fmt, ...) dev_info(dev, "[mcu_wdt] " fmt, ##__VA_ARGS__)
#define mcu_err(dev, fmt, ...)  dev_err(dev, "[mcu_wdt] " fmt, ##__VA_ARGS__)

struct mcu_sequence {
	u8 *data;
	u32 len;
};

struct mcu_wdt {
	struct i2c_client *client;
	struct mutex io_lock;          // I2C总线互斥锁，防止并发发送
	struct delayed_work work;

	struct mcu_sequence init_seq;
	struct mcu_sequence feed_seq;

	u32 feed_interval;            // 喂狗周期 单位秒
};

static void mcu_delay(u8 ms, struct device *dev)
{
	if (!ms)
		return;

	if (ms < 20)
		usleep_range(ms * 1000, ms * 1000 + 500);
	else
		msleep(ms);

	// 延时超过200ms给出警告提示
	if (ms > 200)
		mcu_dbg(dev, "long delay %u ms", ms);
}

static int mcu_send_packet(struct mcu_wdt *wdt, const u8 *buf, u8 len)
{
	int ret;
	struct device *dev = &wdt->client->dev;

	ret = i2c_master_send(wdt->client, buf, len);
	if (ret != len) {
		mcu_err(dev, "i2c send fail, write %d/%u bytes", ret, len);
		return ret >= 0 ? -EIO : ret;
	}
	mcu_dbg(dev, "send i2c buf len=%u ok", len);
	return 0;
}

static int mcu_run_sequence(struct mcu_wdt *wdt, struct mcu_sequence *seq)
{
	u32 pos = 0;
	u8 pkt_len, delay_ms;
	int ret;
	struct device *dev = &wdt->client->dev;

	if (!seq || seq->len == 0 || !seq->data)
		return 0;

	mutex_lock(&wdt->io_lock);
	while (pos < seq->len) {
		// 校验头部2字节是否存在
		if (pos + 2 > seq->len) {
			mcu_err(dev, "seq pos overflow, missing len/delay header");
			ret = -EINVAL;
			goto unlock_exit;
		}

		pkt_len = seq->data[pos++];
		delay_ms = seq->data[pos++];

		if (pkt_len == 0) {
			mcu_err(dev, "invalid zero packet len at pos %u", pos - 2);
			ret = -EINVAL;
			goto unlock_exit;
		}
		if (pkt_len > MCU_WDT_MAX_PACKET) {
			mcu_err(dev, "packet %u exceed max limit %d", pkt_len, MCU_WDT_MAX_PACKET);
			ret = -EINVAL;
			goto unlock_exit;
		}
		// 校验剩余数据是否足够本次包
		if (pos + pkt_len > seq->len) {
			mcu_err(dev, "seq data truncated at pos %u", pos);
			ret = -EINVAL;
			goto unlock_exit;
		}

		// 发送I2C数据包
		ret = mcu_send_packet(wdt, &seq->data[pos], pkt_len);
		if (ret)
			goto unlock_exit;

		pos += pkt_len;
		mcu_delay(delay_ms, dev);
	}
	ret = 0;
unlock_exit:
	mutex_unlock(&wdt->io_lock);
	return ret;
}

static int mcu_parse_sequence(struct device *dev, const char *name, struct mcu_sequence *seq)
{
	int elem_cnt;

	elem_cnt = of_property_count_u8_elems(dev->of_node, name);
	if (elem_cnt < 0) {
		seq->data = NULL;
		seq->len = 0;
		mcu_dbg(dev, "prop %s not present", name);
		return 0;
	}

	seq->data = devm_kmalloc(dev, elem_cnt, GFP_KERNEL);
	if (!seq->data) {
		mcu_err(dev, "alloc %s buf failed size %d", name, elem_cnt);
		return -ENOMEM;
	}
	seq->len = elem_cnt;

	return of_property_read_u8_array(dev->of_node, name, seq->data, elem_cnt);
}

static int mcu_check_sequence(struct device *dev, struct mcu_sequence *seq)
{
	u32 pos = 0;
	u8 pkt_len;

	if (seq->len == 0)
		return 0;

	while (pos < seq->len) {
		if (pos + 2 > seq->len)
			return -EINVAL;

		pkt_len = seq->data[pos];
		if (pkt_len == 0 || pkt_len > MCU_WDT_MAX_PACKET)
			return -EINVAL;

		pos += 2;
		if (pos + pkt_len > seq->len)
			return -EINVAL;
		pos += pkt_len;
	}
	return 0;
}

static int mcu_parse_dt(struct mcu_wdt *wdt)
{
	struct device *dev = &wdt->client->dev;
	int ret;

	ret = of_property_read_u32(dev->of_node, "feed-interval", &wdt->feed_interval);
	if (ret) {
		mcu_err(dev, "dt missing feed-interval property");
		return ret;
	}
	// 周期范围限制
	if (wdt->feed_interval < MCU_WDT_MIN_INTERVAL || wdt->feed_interval > MCU_WDT_MAX_INTERVAL) {
		mcu_err(dev, "feed interval %u out of range [%d~%d]",
			wdt->feed_interval, MCU_WDT_MIN_INTERVAL, MCU_WDT_MAX_INTERVAL);
		return -EINVAL;
	}

	// 解析初始化序列（可选）
	ret = mcu_parse_sequence(dev, "init-sequence", &wdt->init_seq);
	if (ret)
		return ret;
	// 解析喂狗序列（必选）
	ret = mcu_parse_sequence(dev, "feed-sequence", &wdt->feed_seq);
	if (ret)
		return ret;
	if (wdt->feed_seq.len == 0) {
		mcu_err(dev, "dt feed-sequence empty, driver stop");
		return -EINVAL;
	}

	// 校验序列格式合法性
	ret = mcu_check_sequence(dev, &wdt->init_seq);
	if (ret) {
		mcu_err(dev, "init-sequence format invalid");
		return ret;
	}
	ret = mcu_check_sequence(dev, &wdt->feed_seq);
	if (ret) {
		mcu_err(dev, "feed-sequence format invalid");
		return ret;
	}

	mcu_info(dev, "parse dt ok, feed interval=%u sec", wdt->feed_interval);
	if (wdt->init_seq.len)
		mcu_info(dev, "load init-sequence total len=%u", wdt->init_seq.len);
	mcu_info(dev, "load feed-sequence total len=%u", wdt->feed_seq.len);
	return 0;
}

static void mcu_feed_work(struct work_struct *work)
{
	struct delayed_work *dwork = to_delayed_work(work);
	struct mcu_wdt *wdt = container_of(dwork, struct mcu_wdt, work);
	struct device *dev = &wdt->client->dev;
	int ret;

	mcu_dbg(dev, "start feed watchdog");
	ret = mcu_run_sequence(wdt, &wdt->feed_seq);
	if (ret)
		mcu_err(dev, "feed sequence run failed ret=%d", ret);

	// 重新调度下一次喂狗
	schedule_delayed_work(&wdt->work, msecs_to_jiffies(wdt->feed_interval * 1000));
}

#if LINUX_VERSION_CODE < KERNEL_VERSION(6,3,0)

static int mcu_wdt_probe(struct i2c_client *client,
			 const struct i2c_device_id *id)

#else

static int mcu_wdt_probe(struct i2c_client *client)

#endif
{
	struct mcu_wdt *wdt;
	int ret;
	struct device *dev = &client->dev;

	wdt = devm_kzalloc(dev, sizeof(*wdt), GFP_KERNEL);
	if (!wdt)
		return -ENOMEM;
	wdt->client = client;
	mutex_init(&wdt->io_lock);
	i2c_set_clientdata(client, wdt);

	// 初始化延时工作
	INIT_DELAYED_WORK(&wdt->work, mcu_feed_work);

	ret = mcu_parse_dt(wdt);
	if (ret)
		return ret;

	// 执行一次初始化序列
	if (wdt->init_seq.len > 0) {
		mcu_info(dev, "execute init-sequence");
		ret = mcu_run_sequence(wdt, &wdt->init_seq);
		if (ret) {
			mcu_err(dev, "init sequence execute failed, probe abort");
			return ret;
		}
		mcu_info(dev, "init-sequence finished");
	}

	// 启动喂狗延时任务，立刻执行第一次喂狗
	schedule_delayed_work(&wdt->work, msecs_to_jiffies(100));
	mcu_info(dev, "MCU watchdog driver probe success");
	return 0;
}

static void mcu_wdt_remove(struct i2c_client *client)
{
	struct mcu_wdt *wdt = i2c_get_clientdata(client);
	struct device *dev = &client->dev;

	// 同步等待工作完成再退出
	cancel_delayed_work_sync(&wdt->work);
	mcu_info(dev, "watchdog delayed work canceled, driver removed");
}

static void mcu_wdt_shutdown(struct i2c_client *client)
{
	struct mcu_wdt *wdt = i2c_get_clientdata(client);
	cancel_delayed_work_sync(&wdt->work);
}

#ifdef CONFIG_PM_SLEEP
static int mcu_suspend(struct device *dev)
{
	struct i2c_client *client = to_i2c_client(dev);
	struct mcu_wdt *wdt = i2c_get_clientdata(client);

	// 休眠前停止喂狗任务
	cancel_delayed_work_sync(&wdt->work);
	mcu_dbg(dev, "suspend stop feed work");
	return 0;
}

static int mcu_resume(struct device *dev)
{
	struct i2c_client *client = to_i2c_client(dev);
	struct mcu_wdt *wdt = i2c_get_clientdata(client);

	// 唤醒后延迟200ms再喂狗，避免I2C总线瞬间抢占
	schedule_delayed_work(&wdt->work, msecs_to_jiffies(200));
	mcu_dbg(dev, "resume restart feed work");
	return 0;
}

static SIMPLE_DEV_PM_OPS(mcu_pm_ops, mcu_suspend, mcu_resume);
#define MCU_PM (&mcu_pm_ops)
#else
#define MCU_PM NULL
#endif

static const struct of_device_id mcu_of_match[] = {
	{ .compatible = "common,mcu-i2c-wdt" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, mcu_of_match);

static struct i2c_driver mcu_driver = {
	.driver = {
		.name = "common-mcu-wdt",
		.pm = MCU_PM,
		.of_match_table = mcu_of_match,
	},
	.probe = mcu_wdt_probe,
	.remove = mcu_wdt_remove,
	.shutdown = mcu_wdt_shutdown,
};

module_i2c_driver(mcu_driver);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("ChatGPT");
MODULE_DESCRIPTION("Generic I2C MCU Watchdog Driver (DTS configurable sequence)");
MODULE_ALIAS("i2c:common-mcu-i2c-wdt");