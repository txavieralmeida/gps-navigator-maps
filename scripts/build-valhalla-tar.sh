#!/usr/bin/env bash
# Build a Valhalla tile_extract (.tar) from an OSM .pbf using the official Docker image.
# Usage: build-valhalla-tar.sh <input.osm.pbf> <output.tar>
set -euo pipefail

PBF="$(readlink -f "$1")"
OUT="$(readlink -f "$2")"
WORK="$(dirname "$PBF")/valhalla_work"
mkdir -p "$WORK"
cp "$PBF" "$WORK/data.osm.pbf"

docker run --rm -v "${WORK}:/data" ghcr.io/valhalla/valhalla:latest bash -c "
    set -e
    valhalla_build_config \
        --mjolnir-tile-dir /data/valhalla_tiles \
        --mjolnir-tile-extract /data/valhalla_tiles.tar \
        --mjolnir-timezone /data/timezones.sqlite \
        --mjolnir-admin /data/admins.sqlite > /data/valhalla.json
    valhalla_build_timezones /data/valhalla.json
    valhalla_build_admins --config /data/valhalla.json /data/data.osm.pbf || true
    valhalla_build_tiles --config /data/valhalla.json /data/data.osm.pbf
    valhalla_build_extract --config /data/valhalla.json -e /data/valhalla_tiles.tar
"

cp "${WORK}/valhalla_tiles.tar" "$OUT"
rm -rf "$WORK"
echo "Valhalla tar: $OUT ($(du -h "$OUT" | cut -f1))"
