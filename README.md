# ⚠️ ARCHIVED - This repository is no longer maintained

**This repository has been archived and is no longer actively maintained.**

This project was last updated on 2014-10-21 and is preserved for historical reference only.

- 🔒 **Read-only**: No new issues, pull requests, or changes will be accepted
- 📦 **No support**: This code is provided as-is with no support or updates
- 🔍 **For reference only**: You may fork this repository if you wish to continue development

For current CARTO projects and actively maintained repositories, please visit: https://github.com/CartoDB

---

OSM import for CartoDB with Imposm3
===================================

This document describes how you can import OpenStreetMap data into a PostGIS database ready for use with the CartoDB SQL API.

This document expects a Ubuntu 14.04 installation with a `ubuntu` user and enough storage in `/mnt`. PostGIS should be running on `localhost` with user/password `osm` and a database named `osm`. Adapt the following commands if your environment differs.


Preparation
-----------

Create directories:

    sudo mkdir /mnt/osm_data
    sudo mkdir /mnt/imposm3_cache
    sudo chown ubuntu /mnt/osm_data
    sudo chown ubuntu /mnt/imposm3_cache/

Fetch the current imposm3 binaries from http://imposm.org/static/rel/:

    mkdir ~/imposm3
    cd ~/imposm3
    wget http://imposm.org/static/rel/imposm3-0.1dev-20140811-3f3c12e-linux-x86-64.tar.gz
    tar zxvf imposm3-0.1dev-20140811-3f3c12e-linux-x86-64.tar.gz
    ln -s imposm3-0.1dev-20140811-3f3c12e-linux-x86-64 latest

Fetch and verify the OSM planet file:

    cd /mnt/osm_data
    curl http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf.md5
    wget http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf
    md5sum planet-latest.osm.pbf


Copy `cartodb_mapping.json` file to `~/imposm3/`.

Import
------

Start the import (from screen or nohup session):

    ~/imposm3/latest/imposm3 import \
        -read /mnt/osm_data/planet-latest.osm.pbf \
        -write \
        -cachedir /mnt/imposm3_cache \
        -connection 'postgis://osm:osm@localhost:5432/osm?sslmode=disable&prefix=NONE' \
        -dbschema-import public
        -mapping /home/ubuntu/imposm3/cartodb_mapping.json \
        -diff
        -srid 4326

This should take a few hours. You can leave the `-diff` out if you don't plan to update the database.

You can also write most commandline options (except `-read`/`-write`/`-deployproduction`/etc.) into a JSON configuration file:

    {
        "cachedir": "/mnt/imposm3_cache",
        "connection": "postgis://osm:osm@localhost:5432/osm?sslmode=disable&prefix=NONE",
        "mapping": "/home/ubuntu/imposm3/cartodb_mapping.json",
        "srid": 4326
    }

Use the `-config` option to refer to this JSON config. For example:

    ~/imposm3/latest/imposm3 import \
        -config config.json \
        -read /mnt/osm_data/planet-latest.osm.pbf \
        -write \
        -dbschema-import public \
        -diff \
        -overwritecache



Updates
-------

You can update the database minutely, hourly or daily with Osmosis and Imposm 3. We will use hourly updates in this example.

### Preparation

First install Osmosis:

    mkdir -p ~/osmosis
    ~/osmosis
    wget http://bretth.dev.openstreetmap.org/osmosis-build/osmosis-latest.tgz
    tar -xzf ./osmosis-latest.tgz


Initialize the `osm_data` directory:

    ~/osmosis/bin/osmosis --read-replication-interval-init workingDirectory=osm_data


The `osm_data/state.txt` file needs to contain the OSM update sequence from before the creation date your planet file that you imported.
You can [get the sequence from a specific time with this online tool](http://osm.personalwerk.de/replicate-sequences/). You need to select a time before the planet file was created, otherwise you will miss some data.

You can create the file with the following command (change the date in the URL):

    curl 'http://osm.personalwerk.de/replicate-sequences/?Y=2014&m=09&d=10&H=12&i=00&s=00&stream=hour' > osm_data/state.txt

You also need to update the Osmosis configuration to use the hourly diffs. You can copy the `osmosis-configuration.txt` to `osm_data/configuration.txt`.

### Updates

To update the PostGIS database you will need to call Osmosis at first. Osmosis will download all new diff files and will create a single diff file with all pending changes. Then you need to call Imposm to import that combined diff file.

You can use the `imposm3-update.sh` script to do this for you. The first updates should take a while since it needs to update more than one hour at a time to catch up from the time the planet file was created.

You can create a cron job to do this update every hour if the script works:

    10 * * * * /home/ubuntu/imposm3/imposm3-update.sh >> /home/ubuntu/osm_data/update.log 2>&1

