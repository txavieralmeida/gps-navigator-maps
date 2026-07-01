#!/usr/bin/env bash
# Build a Valhalla tile_extract (.tar) from an OSM .pbf using the official Docker image.
# Usage: build-valhalla-tar.sh <input.osm.pbf> <output.tar>
#
# IMPORTANT: the tile binary format is version-specific. The on-device reader is
# the `io.github.rallista:valhalla-mobile` library, which bundles Valhalla 3.5.0.
# Tiles MUST be built with the SAME Valhalla version, or routing fails at runtime
# with: ValhallaError(code=-1, "Action not supported tile").
# Never use the floating `:latest` tag (it drifted to 3.7.0 and broke routing).
set -euo pipefail

VALHALLA_VERSION="${VALHALLA_VERSION:-3.5.0}"
IMAGE="ghcr.io/valhalla/valhalla:${VALHALLA_VERSION}"

PBF="$(readlink -f "$1")"
OUT="$(readlink -f "$2")"
WORK="$(dirname "$PBF")/valhalla_work"
mkdir -p "$WORK"
cp "$PBF" "$WORK/data.osm.pbf"

docker run --rm -v "${WORK}:/data" "$IMAGE" bash -c "
    set -e
    valhalla_build_config \
        --mjolnir-tile-dir /data/valhalla_tiles \
        --mjolnir-tile-extract /data/valhalla_tiles.tar \
        --mjolnir-timezone /data/timezones.sqlite \
        --mjolnir-admin /data/admins.sqlite > /data/valhalla.json
    valhalla_build_timezones /data/valhalla.json
    valhalla_build_admins --config /data/valhalla.json /data/data.osm.pbf || true
    valhalla_build_tiles --config /data/valhalla.json /data/data.osm.pbf
    # In 3.5.0, build_extract (no -e) packs mjolnir.tile_dir -> mjolnir.tile_extract.
    valhalla_build_extract --config /data/valhalla.json -O
    # The container runs as root, so everything written into the bind-mounted
    # /data is owned by root. Hand it back to the host user, otherwise the
    # cleanup 'rm -rf' below fails with 'Permission denied' and (under set -e)
    # kills the whole step even though the tar was built fine.
    chown -R $(id -u):$(id -g) /data
"

cp "${WORK}/valhalla_tiles.tar" "$OUT"
rm -rf "$WORK"
echo "Valhalla tar: $OUT ($(du -h "$OUT" | cut -f1))"
