import os
import pyrosm
import geopandas

from pathlib import Path


os.chdir("/pine/scr/a/c/acgold")
Path("output/osm/ways").mkdir(parents=True, exist_ok= True)
Path("output/osm/edges").mkdir(parents=True, exist_ok= True)
 
# Download, parse, and save OSM data from PBF
# fp = pyrosm.get_data("North Carolina") # Washington DC
fp = "output/osm/north-carolina-latest.osm.pbf"

osm = pyrosm.OSM(fp)

drive_net = osm.get_network(network_type="driving", extra_attributes=["bridge", "tunnel"])
osm_ways = drive_net[drive_net.bridge.isnull() & drive_net.tunnel.isnull()].to_crs(6346)
osm_ways.to_file("output/osm/ways/osm_ways.gpkg")

nodes, edges = osm.get_network(nodes=True, network_type="driving", extra_attributes=["bridge", "tunnel"])
osm_edges = edges[edges.bridge.isnull() & edges.tunnel.isnull()].to_crs(6346)
osm_edges.to_file("output/osm/ways/osm_ways.gpkg")

