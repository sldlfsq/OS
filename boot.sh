#!/bin/bash

echo "Hello, yuanshenqidong!"

cd /home/bochs/bochs/bin
sudo rm hd60M.img.lock
sudo ./bochs -f bochsrc.disk
