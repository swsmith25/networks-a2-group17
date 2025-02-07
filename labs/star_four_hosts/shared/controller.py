#!/usr/bin/env python3
import argparse
import os
import sys
from time import sleep

import grpc

# Import P4Runtime lib from parent utils dir
# Probably there's a better way of doing this.
# sys.path.append(
#     os.path.join(os.path.dirname(os.path.abspath(__file__)),
#                  '/shared/utils/'))
#import utils.p4runtime_lib.switch as switch
import utils.p4runtime_lib.bmv2 as bmv2
import utils.p4runtime_lib.helper as helper
from utils.p4runtime_lib.error_utils import printGrpcError
from utils.p4runtime_lib.switch import ShutdownAllSwitchConnections

ENABLED_PORT  = [1,2,3,4]
TIMEOUT_SEC = 15

def main(p4info_file_path, bmv2_file_path):
    # Instantiate a P4Runtime helper from the p4info file
    p4info_helper = helper.P4InfoHelper(p4info_file_path)

    try:
        # Create a switch connection object for s1 and s2;
        # this is backed by a P4Runtime gRPC connection.
        # Also, dump all P4Runtime messages sent to switch to given txt files.
        s1 = bmv2.Bmv2SwitchConnection(
            name='s1',
            address='127.0.0.1:50051',
            device_id=0,
            #proto_dump_file='/logs/s1-p4runtime-requests.txt'
        )
        
        # Send master arbitration update message to establish this controller as
        # master (required by P4Runtime before performing any other write operation)
        s1.MasterArbitrationUpdate()
        s1.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,
                                   bmv2_json_file_path=bmv2_file_path)
        print ("Installed P4 Program using SetForwardingPipelineConfig on %s" % s1.name)

        try:
            digest_id = p4info_helper.get_id('digests', 'mac_learn_digest_t')
            s1.InsertDigest(digest_id)
            print (f"Inserted digest {digest_id}")
        except AttributeError as e:
            print (e)
            print ("MAC learning needs to be implemented in l2_basic_forwarding.p4")
            
        # Add mcast grp
        for port in ENABLED_PORT:
            mc_entry = p4info_helper.buildMulticastGroupEntry(
                port,
                [{'egress_port':p, 'instance':1 } for p in ENABLED_PORT if p != port]
            )
            s1.WritePREEntry(mc_entry)
        
        # TODO: MAC learning
        while (True):
            # read digest message in from switch
            digests = s1.DigestList()
            
            digest_type = digests.WhichOneof('update')
            if (digest_type == 'digest'):
                digest_data = digests.digest.data[0]
                
                eth_src_addr = digest_data.struct.members[0].bitstring
                while (len(eth_src_addr) < 6):
                    eth_src_addr = bytes([0]) + eth_src_addr
                port_id = digest_data.struct.members[1].bitstring
                port_id = int.from_bytes(port_id)
                
                print('Try to add MAC-port mapping')
                print('MAC address: ',':'.join("%02x" % (b) for b in eth_src_addr))
                print('Port: ',port_id)
                
                # TODO: Add table entries to "MyIngress.smac_table" and "MyIngress.dmac_forward"
                # 1. Use p4info_helper's buildTableEntry() method to build a table_entry
                # 2. Set timeout by setting table_entry.idle_timeout_ns
                # 3. Add the table_entry to the switch by calling s1's WriteTableEntry() method
                
            elif (digest_type == 'idle_timeout_notification'):
                # Handle timeout
                table_entries = digests.idle_timeout_notification.table_entry
                for table_entry in table_entries:
                    s1.DeleteTableEntry(table_entry)
                    print("Deleted table entry")
                    print("Table_id: ", table_entry.table_id) 
        
    except KeyboardInterrupt:
        print(" Shutting down.")
    except grpc.RpcError as e:
        printGrpcError(e)

    ShutdownAllSwitchConnections()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='P4Runtime Controller')
    parser.add_argument('--p4info', help='p4info proto in text format from p4c',
                        type=str, action="store", required=False,
                        default='./build/advanced_tunnel.p4.p4info.txt')
    parser.add_argument('--bmv2-json', help='BMv2 JSON file from p4c',
                        type=str, action="store", required=False,
                        default='./build/advanced_tunnel.json')
    args = parser.parse_args()

    if not os.path.exists(args.p4info):
        parser.print_help()
        print("\np4info file not found: %s\nHave you run 'make'?" % args.p4info)
        parser.exit(1)
    if not os.path.exists(args.bmv2_json):
        parser.print_help()
        print("\nBMv2 JSON file not found: %s\nHave you run 'make'?" % args.bmv2_json)
        parser.exit(1)
    main(args.p4info, args.bmv2_json)
