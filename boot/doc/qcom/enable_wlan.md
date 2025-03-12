
## Referer:
  > https://github.com/jhugo/linux/blob/5.5rc2_wifi/README
  
  > https://xdaforums.com/t/configurations-after-flash-the-ubuntu-images-on-nabu.4610535/

## 1. Copy Firmware
  ```
  /lib/firmware/qcom/sdm845/
  /lib/firmware/ath10k/WCN3990/hw1.0/
  ```

## 2. Install Service
  ```
  apt install rmtfs qrtr-tools tqftpserv libqrtr-dev liblzma-dev
  ```
  or
  ```
  https://github.com/andersson/qrtr
  https://github.com/linux-msm/rmtfs
  https://github.com/andersson/pd-mapper
  https://github.com/andersson/tqftpserv
  ```
  **pd-mapper** must compile install.

## 3. Enable Service
  enable service
  ```
  sudo systemctl enable qrtr-ns.service
  sudo systemctl enable rmtfs.service
  sudo systemctl enable pd-mapper.service
  sudo systemctl enable tqftpserv.service
  ```
  disable systemd-networkd
  ```
  sudo systemctl disable systemd-networkd.service
  sudo systemctl mask systemd-networkd.service
  sudo systemctl stop systemd-networkd.service
  ```
  enable NetworkManager
  ```
  sudo systemctl unmask NetworkManager
  sudo systemctl enable NetworkManager
  sudo systemctl start NetworkManager
  ```
