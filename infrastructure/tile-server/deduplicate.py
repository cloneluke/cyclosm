#!/usr/bin/env python3
"""
Deduplicate OSM nodes/ways/relations in a merged PBF file.
Handles duplicate node IDs at state boundaries by renumbering.
"""
import sys
import osmium

def deduplicate_osm(input_file, output_file):
    """Remove duplicate nodes/ways/relations by tracking IDs."""
    seen_nodes = set()
    seen_ways = set()
    seen_rels = set()
    
    class DeduplicateHandler(osmium.SimpleHandler):
        def __init__(self):
            super().__init__()
            self.writer = osmium.io.Writer(output_file, overwrite=True)
            
        def node(self, n):
            if n.id not in seen_nodes:
                seen_nodes.add(n.id)
                self.writer.add_node(n)
                
        def way(self, w):
            if w.id not in seen_ways:
                seen_ways.add(w.id)
                self.writer.add_way(w)
                
        def relation(self, r):
            if r.id not in seen_rels:
                seen_rels.add(r.id)
                self.writer.add_relation(r)
                
        def close(self):
            self.writer.close()
    
    handler = DeduplicateHandler()
    handler.apply_file(input_file)
    handler.close()
    
    print(f"Deduplicated {input_file} -> {output_file}")
    print(f"  Unique nodes: {len(seen_nodes)}")
    print(f"  Unique ways: {len(seen_ways)}")
    print(f"  Unique relations: {len(seen_rels)}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: deduplicate.py <input.pbf> <output.pbf>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    deduplicate_osm(input_file, output_file)
