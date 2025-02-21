/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<48> macAddr_t;
typedef bit<32> ipAddr_t;
header ethernet_t {
    /* TODO: define Ethernet header */
    macAddr_t dst_address;
    macAddr_t src_address;
    bit<16> ether_type; 
}

/* a basic ip header without options and pad */
header ipv4_t {
    /* TODO: define IP header */ 
    bit<4> version;
    bit<4> header_length;
    bit<8> type_of_service;
    bit<16> length;
    bit<16> identification;
    bit<3> flags;
    bit<13> offset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> checksum;
    ipAddr_t src_address;
    ipAddr_t dst_address;
}

struct metadata {
    ipAddr_t next_hop;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t ipv4;
}

/*************************************************************************
*********************** M A C R O S  ***********************************
*************************************************************************/
#define ETHER_IPV4 0x0800

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        /* TODO: do ethernet header parsing */
        packet.extract(hdr.ethernet);
        /* if the frame type is IPv4, go to IPv4 parsing */ 
        transition select(hdr.ethernet.ether_type) {
            ETHER_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {
        /* TODO: verify checksum using verify_checksum() extern */
        /* Use HashAlgorithm.csum16 as a hash algorithm */ 
    }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* define actions */
    action drop() {
        mark_to_drop(standard_metadata);
    }

    action forward_to_port(bit<9> egress_port, macAddr_t egress_mac) {
        /* TODO: change the packet's source MAC address to egress_mac */
        /* Then set the egress_spec in the packet's standard_metadata to egress_port */
        hdr.ethernet.src_address = egress_mac;
        standard_metadata.egress_spec = egress_port;
    }
   
    action decrement_ttl() {
        /* TODO: decrement the IPv4 header's TTL field by one */
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action forward_to_next_hop(ipAddr_t next_hop){
        /* TODO: write next_hop to metadata's next_hop field */
        meta.next_hop = next_hop;
    }

    action change_dst_mac (macAddr_t dst_mac) {
        /* TODO: change a packet's destination MAC address to dst_mac*/
        hdr.ethernet.dst_address = dst_mac;
    }

    /* define routing table */
    table ipv4_route {
        /* TODO: define a static ipv4 routing table */
        /* Perform longest prefix matching on dstIP then */
        /* record the next hop IP address in the metadata's next_hop field*/
        key = {
            hdr.ipv4.dst_address: lpm;
        }
        actions = {
            forward_to_next_hop;
            drop;
        }
        size = 1024;
        default_action = drop;
    }

    /* define static ARP table */
    table arp_table {
        /* TODO: define a static ARP table */
        /* Perform exact matching on metadata's next_hop field then */
        /* modify the packet's src and dst MAC addresses upon match */
        key = {
            meta.next_hop: exact;
        }
        actions = {
            change_dst_mac;
            drop;
        }
        size = 1024;
        default_action = drop;
    }


    /* define forwarding table */
    table dmac_forward {
        /* TODO: define a static forwarding table */
        /* Perform exact matching on dstMAC then */
        /* forward to the corresponding egress port */ 
        key = {
            hdr.ethernet.dst_address: exact;
        }
        actions = {
            forward_to_port;
            drop;
        }
        size = 1024;
        default_action = drop;
    }
   
    /* applying dmac */
    apply {
        /* TODO: Implement a routing logic */
        /* 1. Lookup IPv4 routing table */
        ipv4_route.apply();
        // TODO: handle drop for both parts
        // if (standard_metadata.egress_spec == DROP_PORT) return;
        /* 2. Upon hit, lookup ARP table */
        arp_table.apply();
        /* 3. Upon hit, Decrement ttl */
        decrement_ttl();
        /* 4. Then lookup forwarding table */  
        dmac_forward.apply();
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {


    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        /* TODO: calculate the modified packet's checksum */
        /* using update_checksum() extern */
        /* Use HashAlgorithm.csum16 as a hash algorithm */
    } 
}


/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
