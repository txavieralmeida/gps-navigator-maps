#!/usr/bin/env bash
# Build all offline datasets for one region from Geofabrik:
#   <code>.tar            Valhalla routing tiles
#   <code>.mbtiles        Shortbread basemap (visual map, downloaded as-is)
#   <code>.search.sqlite  geocoding index
#
# Usage: build-region.sh <code> <geofabrik_path> <out_dir>
#   e.g. build-region.sh portugal europe/portugal out/portugal
set -euo pipefail

CODE="$1"; GEOFABRIK="$2"; OUT="$3"
BASE="https://download.geofabrik.de/${GEOFABRIK}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

echo "==> [$CODE] Downloading OSM extract"
curl -L --fail --progress-bar -o "$OUT/$CODE.osm.pbf" "${BASE}-latest.osm.pbf"

echo "==> [$CODE] Downloading Shortbread mbtiles (basemap)"
curl -L --fail --progress-bar -o "$OUT/$CODE.mbtiles" "${BASE}-shortbread-1.0.mbtiles"

echo "==> [$CODE] Building Valhalla routing tiles"
bash "$HERE/build-valhalla-tar.sh" "$OUT/$CODE.osm.pbf" "$OUT/$CODE.tar"

echo "==> [$CODE] Building search index"
python3 "$HERE/build-search-index.py" "$OUT/$CODE.osm.pbf" "$OUT/$CODE.search.sqlite"

rm -f "$OUT/$CODE.osm.pbf"   # source pbf not published
echo "==> [$CODE] Done:"
ls -lh "$OUT"
