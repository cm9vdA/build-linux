// SPDX-License-Identifier: GPL-2.0

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/i2c.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/workqueue.h>
#include <linux/slab.h>
#include <linux/version.h>

#define FEED_INTERVAL      (10 * HZ)
#define MCU_REG_FEED       0x20
#define MCU_FEED_VALUE     0x01

struct mcu_wdt {
    struct i2c_client *client;
    struct delayed_work feed_work;
};

static void mcu_feed_work(struct work_struct *work)
{
    struct delayed_work *dwork = to_delayed_work(work);
    struct mcu_wdt *wdt =
        container_of(dwork, struct mcu_wdt, feed_work);

    int ret;

    ret = i2c_smbus_write_byte_data(wdt->client,
                                    MCU_REG_FEED,
                                    MCU_FEED_VALUE);

    if (ret < 0)
        dev_err(&wdt->client->dev,
                "feed watchdog failed (%d)\n", ret);
    else
        dev_dbg(&wdt->client->dev,
                "watchdog fed\n");

    schedule_delayed_work(&wdt->feed_work, FEED_INTERVAL);
}

#if LINUX_VERSION_CODE < KERNEL_VERSION(6,3,0)

static int mcu_i2c_probe(struct i2c_client *client,
			 const struct i2c_device_id *id)

#else

static int mcu_i2c_probe(struct i2c_client *client)

#endif
{
    struct mcu_wdt *wdt;

    dev_info(&client->dev, "MCU watchdog probe\n");

    if (!i2c_check_functionality(client->adapter,
                                 I2C_FUNC_SMBUS_BYTE_DATA)) {
        dev_err(&client->dev,
                "SMBus byte data not supported\n");
        return -EOPNOTSUPP;
    }

    wdt = devm_kzalloc(&client->dev,
                       sizeof(*wdt),
                       GFP_KERNEL);
    if (!wdt)
        return -ENOMEM;

    wdt->client = client;

    i2c_set_clientdata(client, wdt);

    INIT_DELAYED_WORK(&wdt->feed_work, mcu_feed_work);

    schedule_delayed_work(&wdt->feed_work, FEED_INTERVAL);

    dev_info(&client->dev,
             "MCU watchdog started\n");

    return 0;
}

static void mcu_i2c_remove(struct i2c_client *client)
{
    struct mcu_wdt *wdt = i2c_get_clientdata(client);

    cancel_delayed_work_sync(&wdt->feed_work);

    dev_info(&client->dev,
             "MCU watchdog stopped\n");
}

static const struct of_device_id mcu_of_match[] = {
    {
        .compatible = "signway,mcu-i2c",
    },
    {
    }
};

MODULE_DEVICE_TABLE(of, mcu_of_match);

static const struct i2c_device_id mcu_i2c_id[] = {
    { "signway,mcu-i2c", 0 },
    { }
};

MODULE_DEVICE_TABLE(i2c, mcu_i2c_id);

static struct i2c_driver mcu_i2c_driver = {
    .driver = {
        .name = "mcu_i2c_wdt",
        .of_match_table = mcu_of_match,
    },
    .probe = mcu_i2c_probe,
    .remove = mcu_i2c_remove,
    .id_table = mcu_i2c_id,
};

module_i2c_driver(mcu_i2c_driver);

MODULE_AUTHOR("ChatGPT");
MODULE_DESCRIPTION("MCU I2C Watchdog");
MODULE_LICENSE("GPL");