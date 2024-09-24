#!/bin/bash

# This bash script will install latest NextCloud on your Orange PI running Armbian and automaticaly optimize the services to match your hardware resources.
# Just run it and let it do it's thing, there's not much to do, this script is not limited to Orange PI and will most likely work on any machine running Armbian, Debian or Ubuntu
# Base64 encoded strings are just gziped configuration files.
# MUNECITO'S NOTE: This is my attempt to modify the original script to use PHP8.3 instead of 8.2

failCheck() {

    EC=$?
    if [[ ${EC} != 0 ]]; then
        echo -e "\e[31mOh no! got error code: \e[93m${EC}\e[0m"
        echo "${1}"
        exit ${EC}
    fi

}

setupNextcloud() {

    echo "Installing system basics"
    apt-get update
    apt-get upgrade -y
    apt-get -y install apt-transport-https lsb-release ca-certificates curl sudo wget zip hdparm
    failCheck "while installing basics, please check output above for more info"
    RELEASE=$(lsb_release -sc)

    if [[ -d /etc/udev/rules.d/ ]]; then
        echo "H4sIAAAAAAAAA1NWKE4tUShOzkhNKc1JLVJIyy9S8AvzTeVydA7x9PeztVVKTEmpSc5IzEtPVdJR8HYN8nP1AYrmleWmRhvoWsZqAUUdQ0KCqgtLU0tT9eEm1QLV5OelKnEpY7EhONhFITEvRSHV19eZkE3FKdGJulWxqNYU5ZcklmTm5yXm1AKVGOB2Q3ZlUmqREiE7cnOTk3KyCfkHahY2D0Hck5eukJJZnF1MBS8Z4nZGUlqhEhcA44K9NrgBAAA=" | base64 -d | gunzip > /etc/udev/rules.d/60-io-scheduler.rules
        echo "H4sIAAAAAAAAA3N0DvH097O1VUpMSalJzkjMS09V0lHwdg3yc/UBihanRCfqVsUChRxDQoKqC0tTS1P1i/JLEksy8/MSc2qBSgyBkkGhftq2SvrFSZl5+hkpBYlFuQq6TgqGRuYKusEKZgYKKql5ZdUurmF+jr6utUpcANKky+t1AAAA" | base64 -d | gunzip > /etc/udev/rules.d/65-disk-power.rules
        udevadm trigger
    fi

    NUMCORES=$(nproc)
    PHPTHREADS=${NUMCORES}
    if [[ ${PHPTHREADS} -lt 1 ]]; then
        PHPTHREADS=1
    fi
    TOTALMEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTALMEM=$((TOTALMEM/1024))
    ROUNDED=1
    while [ ${ROUNDED} -lt ${TOTALMEM} ]; do
        ROUNDED=$((ROUNDED*2))
    done
    if [[ ${TOTALMEM} -gt 400 ]]; then
       PHPTHREADS=$((PHPTHREADS*2))
    fi
    PHPMEM=$((ROUNDED/2))
    OVERDRIVE=$((ROUNDED/1024))
    if [[ ${OVERDRIVE} -gt 8 ]]; then
      OVERDRIVE=8
    fi
    DBMEM=$((PHPMEM/4))
    DBTEMPBUFF=$((DBMEM/16))
    DBWORKMEM=$((DBTEMPBUFF/2))
    REDISMEM=$((DBMEM/4))
    if [[ ${PHPMEM} -lt 128 ]]; then
        PHPMEM="128"
    fi
    if [[ ${PHPMEM} -gt 1024 ]]; then
        PHPTHREADS=$((PHPTHREADS+$((OVERDRIVE*2))))
        DBMEM=$((256*OVERDRIVE))
        DBTEMPBUFF=$((DBMEM/32))
        DBWORKMEM=$((DBTEMPBUFF/2))
        REDISMEM=$((DBMEM/8))
        PHPMEM="1024"
    fi
    THMEM=$((PHPMEM+$((PHPMEM/2))+$((PHPMEM/32))+REDISMEM+DBMEM+DBWORKMEM+DBTEMPBUFF))
    MAXUSERS=$((THMEM*PHPTHREADS))
    MAXUSERS=$((MAXUSERS/1786))

    if [[ -d /nextcloud/ ]]; then
        echo "It seems that NextCloud is already installed? Please review and remove /nextcloud/ to continue"
        exit
    fi
    echo "Creating a user"
    useradd nextcloud --groups www-data --home-dir /var/lib/nextcloud/

    echo "Downloading NextCloud"
    wget https://download.nextcloud.com/server/releases/latest.zip
    failCheck "while downloading NextCloud, please check your internet connection"
    unzip latest.zip
    mv nextcloud/ /nextcloud/
    mkdir -p /nextcloud/data/tmp/
    chown nextcloud:www-data -R /nextcloud/
    rm -rf latest.zip

    echo "Setting up Redis"
    apt-get install -y redis-server
    failCheck "while installing Redis, please check output above for more info"
    echo "Adding user nextcloud to redis group"
    usermod -a -G redis nextcloud
    echo "H4sIAAAAAAAAA31Ta1LjMAz+n1P4AoKkQGG5jWOrxNSvke2U9PQrJRQ6lN1kkpH1ydKn1+iiVcPu+a7nd1Cvr0OXKVU0FS2EZFEtWLqcqKq+qybDqM3Rpzf1NAxdi+6jJHPEqu6pxXtC68r2h4I0I90JfGWXkYJ6fmZXLmBqF6dHxKy9m1E99H1nNYYU3XmLXRpfml1Bq2LqsrMH51Hdz5r+FZNtOqbocUavTpqii2+i+L7Ih98uspqDVz3qgkU9dtqf9MLolE7AWBICRTPLP32vhk18ELHf5L2I/HSlpgwnchULpAjjm8CARInWnMiOJoVMWIpL8Us1oTmWFtazHYVu1AGVbSHfMS42YNFDWaIBgYswso4+s3Ljlk+njWe+EPQHsA/u70vHcuCy0qKGffg+QU7emUVp74/IuXpqndfn5UCIIALg7EwVlhzqB/KRHeGtfqumMBWMMHMEvUEH38p0e6OVb/uUAhSTCEHb9xsFzNo3zrtXOy78C9da54zRpuiXtT0+nSR1+URmv3XS8dKXT/S6MF5XjGYBGbmaxJzbMiVveTYnXabV+Ow4iVIBYyXH4Z+G3S24UlP7x249XSNFhhl2G3DpPCec68RRCm7WLlYRr2OcL9hPAsL8BvwiMHkekqyp4IqPCw+iTCpXi3vJzUEhz2uxjprxjt0Cr2NuFcZ2OHDVvAuuckUpaM/V5vd/dp9NVrunfRiZgfz+eyG3sbRRPezY8mWzns6ySHbhmXcG+CTcdDoA4bpKXB9DGNij9nCQHbgsDqzr9Tv8jpyAT4aXcG2ttqv6L8LUp9L4BAAA" | base64 -d | gunzip > /etc/redis/redis.conf
    sed -i "s/maxmemory 16m/maxmemory ${REDISMEM}m/g" /etc/redis/redis.conf
    service redis-server restart
    failCheck "while starting Redis process, please check output above for more info"

    echo "Setting up PHP 8.3"
    if [[ ${RELEASE} == "bookworm" ]]; then
        echo "Adding SURY repo"
        curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
        sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
        apt-get update
    fi
    apt-get install -y php8.3 php8.3-fpm php8.3-gmp php8.3-bz2 php-bcmath php8.3-intl php8.3-mbstring php8.3-apcu php8.3-xml php8.3-redis php8.3-curl php8.3-zip php8.3-pgsql php8.3-gd php8.3-bcmath php8.3-imagick php8.3-common libmagickcore-6.q16-6-extra imagemagick ffmpeg
    failCheck "while installing PHP8.3, please check output above for more info"
    echo "H4sIAAAAAAAAA2WQzW4CMQyE7/sUPAECVBAccqh6bVWqHhGKQtbZNU3iJfZC26dvoPyE9hbNN3ZmvFoSS5OA39+e11XX8M4Pjfd00B0kRhaIMlCD13hhvZDOdpA/BufOjmA+79F4NCqQx/jBdyo2kRLoSIIWMrnonppSrFbUWWNbWFfnxxCi2XhQ46sQIFD60pYi96ETpKhmD1eKUSBFqDVLwtiw3vTOQVLz23wOaKwFD8lINjr0wGo8m0wWV0+CvfFYZ65dgp1a5CIX5gyL5raXmg6xyPUbVFuPhVgs6oy06raGzT6bKYR8QP6/5phK0x5Swrpsv8XTuSfTaSmdW2rGbzjh+Uu+5ePyqV9XprNDboNmaE5/HflNLAZ+ANhYH7snAgAA" | base64 -d | gunzip > /etc/php/8.2/fpm/conf.d/99-nextcloud.ini
    echo "H4sIAAAAAAAAA31SS0sDMRC+51f04LXNWqRowUPBwhZcXWpvpYS4Gd1gXubRVn+9SdatskUvYb/XZHYmWwVH3wgd2A4hwZ0HNbodYRsUNq3BWakoVxOnm7dvw0QfFNhoO2V74dXqYKJwOBzGjHra81IziHQxmxUIBTcIn6WQkRFqxUBSxSKaSHokTcsFs7m/uqw35ToJzlPrSay4B+uiMs1urogz1MIv4bIvMxSmvWDhPYDz2VwURaKN1Q04RzgTQDyXoINP8nXhEGpaxtOPYIRA7bfl49PmYVEtd5G66EFWNlWdSOylwT1xt1oPuOXQVS82ZWaCs1johgrsnrma/8In+CPkjw7GA8UlEsrSQPZUBNgGIzRlJF5CYve5/GkROA2/u38YkyC1/SCCS+5TqFpW96vqr+ppmi9cgOOfkNxXxc2sGp25XRwt1/Fp0T2QNm5aQO7IAuPuf7ehvk3WoPhxjnF+rznWneNuvd2j/QKMme9C4wIAAA==" | base64 -d | gunzip > /etc/php/8.2/fpm/pool.d/cloud.conf
    sed -i "s/PHPTHR/${PHPTHREADS}/g" /etc/php/8.3/fpm/pool.d/cloud.conf
    sed -i "s/MEMLIM/${PHPMEM}M/g" /etc/php/8.3/fpm/pool.d/cloud.conf
    sed -i "s/opcache.memory_consumption=64/opcache.memory_consumption=$((PHPMEM/4))/g" /etc/php/8.3/fpm/conf.d/99-nextcloud.ini
    sed -i "s/apc.shm_size = 128M/apc.shm_size = $((PHPMEM/4))M/g" /etc/php/8.3/fpm/conf.d/99-nextcloud.ini
    sed -i "s/opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=$((PHPMEM/32))/g" /etc/php/8.3/fpm/conf.d/99-nextcloud.ini
    service php8.3-fpm restart
    failCheck "while starting PHP8.3 process, please check output above for more info"

    echo "Setting up Nginx"
    apt-get install -y nginx-full certbot python3-certbot-nginx
    failCheck "while installing Nginx, please check output above for more info"
    echo "H4sIAAAAAAAAA5VWTY/bNhC9+1cQyC2prP1w3UV9S1OgQBdIgS16JWhqJDHmVzmULKfof+9Qkm3ZlhN0D2vqvcfHGWqGYoMQ2H6/zwoRxWaxd2EHgfvgJCACMtFEt1l4VbA8NDa3lbLdkh43C2WlbgpgOUQ54LlxRaMBM7Biq6HI3y+ls+VmsYAWbET2z4KNfw0CA++03pygcWmaYUFG5Syyn9YvZ940OioupAQfmSvJ9t/Foo7Rk+1J9O7decg+ClSSvUGMylY41ZzGCLYolQbm7HmlKD23zjdYz8AFaHG4wI8e3IiOy7qxO7Yyk2kHD8hrgXUvQPUV2NPD6mVqEFrKPLodUNJ9akdqB+CFVi3wqAy4JrLHpwc88/SiugPfNmUJgZK8iGvgAvzdAMapZrrAIMLoAswRUsh6lkipRDCe95n3ST3Mh4VsvWKr3Tw5zHxcz9B4Mhj3bOpRCoyyUncyP7Lfyf3SZIjz9zn6f4Qyk9BRMLtlR9FJLbWiXuE1iILcpqbTRbUIFfA5LbIX9kLKSR+M9WWFORbitpE7iIPterWZ13JlaQcLFagdh4076eZ6n+pz2df62a6AUlDX8gQz4b1WUqTOzp2MEDOMAYTZ3Onet7fX7/Qu6nRQRSedRvbn61v7OPxfHn+fxt/nDfl9Cs77VANk3D7/wAKUP7M/Pn/+9PrrlSX0Wz5shFS+Tpuayms+zldXVb3tt2JNxxYi1+6qBCEEF3o4b0XIaTBuZ08s6XmybPVV+Ys6TwCneYdbVDoqNE3nrmbPV5Sh96rBVrFmTz+ur8jUfQoKBp2nF18w67LhDKDBcEr4oFoRE8A1VTanQ1+VqpdyiKJKn4z6yrWvi4sKENGZD53RF+AX0QqUQdEBfwGjsxeALj7cYEZYVVKz3zIB8Wal1hbLCtytOBEGs9LZ6LZfUuVP2b1AcwF0vTKLsbyC97DNCMnuh9XV0eibwNJzssydp9ZOfaOMqCDfGj+OsK36WcNTlyn6YrIIXcz7F3VaccQQh4HXQo26VopQjENKNyhDhTasv+xoNFJxtOiyVEzOUjwnIDjErHCGPDP6jCt5uNcef6kQG6HZb45C+oWuA+pOi8ycKen2sDxfI76hRBWn947+bvAfM/rBqNsIAAA=" | base64 -d | gunzip > /etc/nginx/nginx.conf
    echo "H4sIAAAAAAAAA6VWbW/bNhD+vPwKTjOweI1M561pEwRFm7ZrgLUJknwoULcETVEyU4rUSMovC9vfvqMkx7JjJxgmBIpMHp+753hvOS1Qh5qMjOGftdwRkeelo0PJ0d0WgieK4O+k+kx4SkvpUHQvAxs/trYsN2NuQL6SksI6rtCLfn2o3iSK5hyRk1rEaO0QVnzqmNRlgueSKkkFKNaqkWNScOVITqdkqJMZseIfjg76L59/PGnvV3tO5FyXDr3s921znCYJGXGagG1XPOXGcBNfainYDK19IqVj0whG4byc0Jk9WcX6HJ9pBRRdfDMreHxROKGVfYhllUjTqPm9EeutniipabIBp8HSBVdzqM1Y7w14+RGggHX9+uO7i6vzP88/RY9gXTsjGBA0VNlCGxdfc1Ya4ZY8F+0eHh7u9fv96Am7LrnJhXM8ic+MthY451So+i4Etw1HxaMF9kasKz3UzsY3NFtPsMYSKuHTHaR0qqXUk2gz3ufr6/jSaMdZ8Np6vN0TlOuEnw6lZt+XsVJqHcsEGYmEtwjrCTdA982sCUWhmCwTjnKI0p6DsGmOV59NplW/ISfwLR1Ty4woHLq1KL8F2V9oUYCzaLART6jNUXjVGD/mKoBy/e4Vo6L5GrlcIny/2jH875JbR+AyG9OAUwWLThFuWSJStI06I+cKUkIOE5pBxKOf6NtbOj6T8NltCYfHcFcahfb7ewgbnoNHg0I84cOEjnFHWAJ1xoZi03CvbW8xaFtiqmvuualrqaHhLsN7ASB1RpR2JNWlSpBO08UWZYxbS0Bisb6q6dtPhHsTLmX8XUEizmvYqjUtEcyoSYARulsw3l1iHOieNMweB5IB52mgh0hLOJRB0rMRuIWrjAe5O+TMjIRaalEHbrp6YXR60D9Ya9gSXPFdxGMqRULnCfEE3D1em8aGiFt3BxBTePvV8bAUMvEORK1nWqUi81IM/b5JCmrcDHbyQlLY92AZ7cKJjsfdlvta7FaxBz1PS6cDuNeMeWFtyT3YKLhPhiTos1ry7mrmr2Kvgg8Cw7kld21PTKBY8kr5r5UrfH2vviiHkMeeGa1Aq+EDTG/pdIDLAlhxbx11pQUb7QCPv+zuffX1hhng3jNY/pLbr3Fh9BjKTb3WezbAUKtHiWZlDilqGVSqAQaZ6az7eOaHZ16/LJQXRwrqRkSoVKNv271nryp63W3c+6PbWeQVTAmos5DszCHul1rwrcC511RVtnogqEJoIT2vkgtEaGitarG0jq7Prs4vb8j787/efYKmhjpzF5AwX6zTtwnp8vXNB3L+6f1Fi9cmWWgEH6oyb1+PqZDVpORMuRE7hZt2BALMGWhFoZBCoxlvPmMtKpWYHmOMTQnZCHWgGpI+QsfsWeg/Dw8ZsOd+/tmv5p9VEQEDi2Ec/ADTjTZ2MWOtC2qIaGatv7Uemo+348xnIvWFyvxtkXnBtA/dx7sUYob7nBZeZ5lPJWXdTruZLVeNx2pCeFpt+YyyEa/GLHAaiuqk2UEwCMbQh053D4+OXhw83995MLRGG8t/tfYbqocjKo/RW61+d6F/NJLIaVSh2TUFN3glcO6sNL1mJCahj6PVHv1Um6tAwba9V//Da3xaCAPCR8l/63xNo2kpXt+Fnq7feLPxdaN4ohn82PoXK3WLXYYMAAA=" | base64 -d | gunzip > /etc/nginx/sites-available/nextcloud
    ln -s /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/
    rm /etc/nginx/sites-enabled/default
    service nginx restart
    failCheck "while starting Nginx process, please check output above for more info"

    echo "Setting up PostgreSQL"
    DBPASS=$(openssl rand -base64 16)
    export DBPASS
    export DBNAME="nextclouddb"
    export DBUSER="nextcloud"
    apt-get install -y postgresql
    usermod -a -G postgres nextcloud
    failCheck "while installing PostgreSQL, please check output above for more info"
    POSTGRESPATH=$(find /etc/postgresql/ -name postgresql.conf)
    POSTGRESHBAPATH=$(find /etc/postgresql/ -name pg_hba.conf)
    sed -i "s/shared_buffers = 128MB/shared_buffers = ${DBMEM}MB/g" "${POSTGRESPATH}"
    sed -i "s/#work_mem = 4MB/work_mem = ${DBWORKMEM}MB/g" "${POSTGRESPATH}"
    sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = ${DBWORKMEM}MB/g" "${POSTGRESPATH}"
    sed -i "s/#temp_buffers = 8MB/temp_buffers = ${DBTEMPBUFF}MB/g" "${POSTGRESPATH}"
    sed -i "s/#effective_cache_size = 4GB/effective_cache_size = ${PHPMEM}MB/g" "${POSTGRESPATH}"
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '127.0.0.1'/g" "${POSTGRESPATH}"
    SWITCHEROO=$(cat "${POSTGRESHBAPATH}")
    echo "local   ${DBNAME}             ${DBUSER}                               md5" > "${POSTGRESHBAPATH}"
    echo "${SWITCHEROO}" >> "${POSTGRESHBAPATH}"
    service postgresql restart
    failCheck "while starting PostgreSQL process, please check output above for more info"
    echo "CREATE USER ${DBUSER} WITH PASSWORD '${DBPASS}'; CREATE DATABASE ${DBNAME} TEMPLATE template0 ENCODING 'UNICODE'; ALTER DATABASE ${DBNAME} OWNER TO ${DBUSER}; GRANT ALL PRIVILEGES ON DATABASE ${DBNAME} TO ${DBUSER};" | sudo -u postgres psql -d template1

}

if [[ ${UID} != 0 ]]; then
    echo "Please run the script as root"
    exit
fi

cd /root/ || exit
echo "Installing Nextcloud on your machine"
setupNextcloud

clear
echo "Installing Nextcloud database"
chmod +x /nextcloud/occ
ADMPASS=$(openssl rand -hex 16)
export ADMPASS
sudo -u nextcloud /nextcloud/occ maintenance:install --database pgsql --database-name "${DBNAME}" --database-host /run/postgresql --database-user "${DBUSER}" --database-pass "${DBPASS}" --admin-user admin --admin-pass "${ADMPASS}"
sleep 3
if (grep "'installed' => true," /nextcloud/config/config.php); then
    echo "Installation complete!"
    sed -i "s/localhost/$(hostname -I | awk '{print $1}')/g" /nextcloud/config/config.php
else
    echo "Oh no!, it seems that the installation has failed,"
    echo "go tell that lazy fuck who wrote this crap to fix it!"
    echo ""
    echo "(and also provide him the contents of /var/log/nextcloud.log)"
    exit
fi

echo "Optimizing"
sed -i '$ d' /nextcloud/config/config.php
echo "H4sIAAAAAAAAA32TYY/TMAyGv9+v6LcKCdbuDiEkBBI7YAJpUMEJncRQlTXeFi5NgpN23b/HiwtlGqEfqtbPW8d+XWdZLjcO0CsfwIQ8e/kqC9jB46uMCGxFp0Pt9tZAjbBT1kRFvlzkUfHDwa7+2QmtwpHJs5IJGLHRUDuEXsHBnydmKCuGFdpeSaohir6RgK/80+16lKwXqyrmvSTL9+8S5EP1dplAX76myErgwxt7MClc3aQINQEJVn1MHXd3f5cg9wsVWuEi/R5dG72sWzHUA7s9L8vR77/h8X/QN4LmshVNsBh18/JM01jTdIhgmmMttI6Sm6TCwIGTXJzTQmuRK5lfP49Y252GHjjn09+hrdLABRe9wIIihYEhNNp2ckZv3AKla0SzB4pQA6xfk12rMb5+Xd12l9IHZXb/EH8GqTyrMT6e/Xn53npahdMVy8LOFFHG9ycesAeceUo/DS93FqePyikuN8pIoIH98YnjQbVgu8Dx62nMAVonFcJpQOMkJ0MKKYIoQusKrv5k3tjmbNyq81Xz4D2tLW2vFgPIGganxrRboT2JHr24+gWXXa/TBgQAAA==" | base64 -d | gunzip >> /nextcloud/config/config.php
sed -i "s/'preview_max_memory' => 128,/'preview_max_memory' => $((PHPMEM/2)),/g" /nextcloud/config/config.php
sed -i "s/'preview_concurrency_all' => 3,/'preview_concurrency_all' => $((NUMCORES*2)),/g" /nextcloud/config/config.php
sed -i "s/'preview_concurrency_new' => 1,/'preview_concurrency_new' => $((NUMCORES/2)),/g" /nextcloud/config/config.php
echo "Adding Cronjob"
echo "*/5 * * * * php --define apc.enable_cli=1 -f /nextcloud/cron.php" > /tmp/cron
echo "*/10 * * * * php --define apc.enable_cli=1 -f /nextcloud/occ preview:pre-generate" >> /tmp/cron
crontab -u nextcloud /tmp/cron
rm /tmp/cron
touch /var/log/nextcloud.log
chown nextcloud:www-data /var/log/nextcloud.log
echo "Restarting services"
systemctl restart php8.2-fpm.service postgresql.service nginx.service redis-server.service
apt-get clean
echo "Installing command line utility"
echo "H4sIAAAAAAAAA5XMvQrCMBSG4bnnKj5r1xicJeDiDShOpUh+TkggnATSgJfv1t355XnPJ+2yaGd7ohyxrljer8cTxmAW/u6+1BFmbNsNe2KhqaUGpQLHLAzb/IXFusIfX7K5Qh9GV++x3IlLZ5r6CBVq4Mj49xMz/QDKN/0grAAAAA==" | base64 -d | gunzip > /usr/local/bin/nextcloud
chmod +x /usr/local/bin/nextcloud
nextcloud config:app:set files max_chunk_size --value 0
nextcloud config:app:set activity activity_expire_days --value 365
nextcloud db:add-missing-indices
echo "Installing additional apps"
APPS=(previewgenerator calendar contacts mail notes)
for APP in "${APPS[@]}"; do
    echo "installing ${APP} app"
    nextcloud app:install "${APP}"
done
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'
echo -e "${GREEN}Done!${NC}"
echo -e "${BLUE}----------------------------------------------------------------------------${NC}"
echo -e "${GREEN}Machine Resources${NC}"
echo -e "  ${YELLOW}${NUMCORES}${NC} CPU Cores"
echo -e "  ${YELLOW}${TOTALMEM}MB${NC} RAM"
echo -e "${GREEN}Calculated Optimal Values:${NC}"
echo -e "  ${YELLOW}${PHPTHREADS}${NC} PHP threads"
echo -e "  ${YELLOW}${PHPMEM}MB ${NC}PHP memory limit"
echo -e "  ${YELLOW}$((PHPMEM/4))MB${NC} PHP opcache memory limit"
echo -e "  ${YELLOW}$((PHPMEM/4))MB${NC} PHP APCu cache size"
echo -e "  ${YELLOW}$((PHPMEM/32))MB${NC} PHP opcache string buffer"
echo -e "  ${YELLOW}${DBMEM}MB${NC} PostgreSQL shared buffers"
echo -e "  ${YELLOW}${DBWORKMEM}MB${NC} PostgreSQL working memory"
echo -e "  ${YELLOW}${DBTEMPBUFF}MB${NC} PostgreSQL temporary buffer"
echo -e "  ${YELLOW}${REDISMEM}MB${NC} Redis memory limit"
echo -e "  ${YELLOW}$((PHPMEM/2))MB${NC} preview generator memory limit"
echo -e "  ${YELLOW}$((NUMCORES*2))${NC} preview generator concurrency"
echo -e ""
echo -e "${YELLOW}Additional Information:${NC}"
echo -e "  Theoretical peak memory usage: ${YELLOW}${THMEM}MB${NC}"
echo -e "  Installation folder: ${YELLOW}/nextcloud/${NC}"
echo -e "  Data folder: ${YELLOW}/nextcloud/data/${NC}"
echo -e ""
echo -e "${BLUE}----------------------------------------------------------------------------${NC}"
echo -e "Your NextCloud installation is ready and should be able to reliably"
echo -e "serve ${YELLOW}${MAXUSERS}${NC} active users :)"
echo -e ""
echo -e "You can now open this link in your browser to access Nextcloud:"
echo -e ""
echo -e "    ${BLUE}http://$(hostname -I | awk '{print $1}')${NC}"
echo -e ""
echo -e "    ${YELLOW}'admin'${NC} user password: ${YELLOW}${ADMPASS}${NC}"
echo -e ""
echo -e "You can also use the 'nextcloud' command to use the OCC utility."
echo -e "For example, you can change the admin user password with:"
echo -e ""
echo -e "    nextcloud user:resetpassword admin"
echo -e ""
echo -e "${BLUE}----------------------------------------------------------------------------${NC}"
exit
