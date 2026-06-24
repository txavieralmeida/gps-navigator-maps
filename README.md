# gps-navigator-maps

Offline map data for the **GPS Navigator** companion app, built automatically from
[Geofabrik](https://download.geofabrik.de/) OpenStreetMap extracts.

For each region (one folder per country under `regions/`) three datasets are produced:

| Dataset | File | Used for |
|---------|------|----------|
| Routing | `<code>.tar` | Valhalla offline routing tiles |
| Basemap | `<code>.mbtiles` | MapLibre offline visual map (Shortbread schema) |
| Search  | `<code>.search.sqlite` | offline geocoding (named places & streets) |

The large files are published as **GitHub Release assets** (one release per country,
tag = country code). The app reads [`manifest.json`](manifest.json) — the index of all
available regions and their download URLs — and downloads what you choose.

## Automation

`.github/workflows/build-maps.yml` runs **daily**. For each region it compares the
Geofabrik `.pbf` md5 with the last built one (stored in `manifest.json`); if the source
changed, it rebuilds that region and refreshes its release assets + the manifest. So the
data stays **up to date** automatically whenever Geofabrik publishes a new extract.

## Adding a country

Create `regions/<code>/region.json`:

```json
{ "name": "Spain", "code": "spain", "geofabrik": "europe/spain" }
```

The next workflow run builds and publishes it.

## Attribution / License

Map data © **OpenStreetMap contributors**, available under the
[Open Database License (ODbL)](https://www.openstreetmap.org/copyright).
Build scripts in this repo are MIT-licensed.
