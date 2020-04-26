#!/bin/bash

sudo apt update
sudo apt install ffmpeg rtl-sdr -y
git clone https://github.com/F5OEO/rpitx.git
rm install.sh -rf
./transmitter.sh