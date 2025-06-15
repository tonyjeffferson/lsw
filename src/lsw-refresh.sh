#!/bin/bash

bash <(curl https://raw.githubusercontent.com/winapps-org/winapps/main/setup.sh)
sleep 1
git clone https://github.com/winapps-org/winapps.git
cd winapps
bash <(curl https://raw.githubusercontent.com/winapps-org/winapps/main/setup.sh)