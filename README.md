# Minetest Game Server

This is the Minetest Game modpack I use in my private SMP

## Running

Clone this repository and update the submodules:

```bash
git clone https://github.com/AFCMS/mtg_server
cd mtg_server
git submodule update --init --recursive
```

Install Docker and Docker Compose, then run:

```bash
docker-compose up server_survival
```

or

```bash
docker-compose up server_pvp
```

Make a maps backup:

```bash
./backup.sh
```
