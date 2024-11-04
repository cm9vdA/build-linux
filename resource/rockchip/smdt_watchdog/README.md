# SMDT 看门狗

此代码适用于AIoT-3588D

## capture_1 和 capture_2
逻辑分析仪抓到的通信报文

# smdt_watchdog.c
用户空间的喂狗程序

# 3399e关闭看门狗（未验证）
```
i2cset  -f -y 4 0x62 0x32 0x00 b
```
