#!/usr/bin/env python3
"""Build an offline geocoding SQLite index from an OSM .pbf (Geofabrik).

Extracts named features (places, streets, POIs) with coordinates into a compact
SQLite database consumed by the companion app's Rust geocoder (commands/search.rs).

Schema:  places(name TEXT, norm TEXT, lat REAL, lon REAL, kind TEXT)  + index on norm
`norm` = lowercased, accent-stripped name (matches the Rust normalize()).

Usage:  python3 build-search-index.py <region>.osm.pbf <region>.search.sqlite
Requires: pyosmium  (pip install osmium)
"""
import sqlite3
import sys
import unicodedata

import osmium

# Keys whose named features are worth indexing for navigation search.
WANTED_KEYS = (
    "place", "highway", "amenity", "shop", "tourism",
    "leisure", "railway", "aeroway", "natural", "waterway", "building",
)


def normalize(s: str) -> str:
    s = s.strip().lower()
    s = unicodedata.normalize("NFKD", s)
    return "".join(c for c in s if not unicodedata.combining(c))


def kind_of(tags) -> str:
    for k in WANTED_KEYS:
        if k in tags:
            return f"{k}={tags[k]}"
    return ""


class Indexer(osmium.SimpleHandler):
    def __init__(self, conn):
        super().__init__()
        self.cur = conn.cursor()
        self.batch = []
        self.count = 0

    def _add(self, name, lat, lon, kind):
        self.batch.append((name, normalize(name), lat, lon, kind))
        self.count += 1
        if len(self.batch) >= 10000:
            self._flush()

    def _flush(self):
        self.cur.executemany(
            "INSERT INTO places(name,norm,lat,lon,kind) VALUES (?,?,?,?,?)", self.batch
        )
        self.batch.clear()

    def node(self, n):
        if "name" in n.tags and any(k in n.tags for k in WANTED_KEYS):
            if n.location.valid():
                self._add(n.tags["name"], n.location.lat, n.location.lon, kind_of(n.tags))

    def way(self, w):
        if "name" in w.tags and any(k in w.tags for k in WANTED_KEYS):
            lats, lons = [], []
            for nd in w.nodes:
                if nd.location.valid():
                    lats.append(nd.location.lat)
                    lons.append(nd.location.lon)
            if lats:
                self._add(w.tags["name"], sum(lats) / len(lats), sum(lons) / len(lons), kind_of(w.tags))


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    pbf, out = sys.argv[1], sys.argv[2]

    conn = sqlite3.connect(out)
    conn.execute("PRAGMA journal_mode=OFF")
    conn.execute("PRAGMA synchronous=OFF")
    conn.execute("CREATE TABLE places(name TEXT, norm TEXT, lat REAL, lon REAL, kind TEXT)")

    h = Indexer(conn)
    print(f"Indexing {pbf} ...")
    h.apply_file(pbf, locations=True, idx="flex_mem")
    h._flush()

    print(f"Indexed {h.count} features. Creating index ...")
    conn.execute("CREATE INDEX idx_norm ON places(norm)")
    conn.commit()
    conn.execute("VACUUM")
    conn.commit()
    conn.close()
    print(f"Done: {out}")


if __name__ == "__main__":
    main()
