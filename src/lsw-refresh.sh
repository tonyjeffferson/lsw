#!/bin/bash

cd $HOME
bash <(curl https://raw.githubusercontent.com/winapps-org/winapps/main/setup.sh)
sleep 1
git clone https://github.com/winapps-org/winapps.git
cd winapps
bash <(curl https://raw.githubusercontent.com/winapps-org/winapps/main/setup.sh)
cd ..
sleep 1
rm winapps
exit 0