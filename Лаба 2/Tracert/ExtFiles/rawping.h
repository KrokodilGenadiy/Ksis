//////////////////////////////////////////
//for details Visit 
//http://tangentsoft.net/wskfaq/
//////////////////////////////////////////

#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>

// ICMP packet types
#define ICMP_ECHO_REPLY		0
#define ICMP_DEST_UNREACH	3
#define ICMP_TTL_EXPIRE		11
#define ICMP_ECHO_REQUEST	8

// Minimum ICMP packet size, in bytes
#define ICMP_MIN			8

#ifdef _MSC_VER
// The following two structures need to be packed tightly, but unlike
// Borland C++, Microsoft C++ does not do this by default.
#pragma pack(1)
#endif

// The IP header
struct IPHeader 
{
    BYTE	h_len:4;			// Length of the header in dwords
    BYTE	version:4;			// Version of IP
    BYTE	tos;				// Type of service
    USHORT	total_len;			// Length of the packet in dwords
    USHORT	ident;				// unique identifier
    USHORT	flags;				// Flags
    BYTE	ttl;				// Time to live
    BYTE	proto;				// Protocol number (TCP, UDP etc)
    USHORT	checksum;			// IP checksum
    ULONG	source_ip;
    ULONG	dest_ip;
};

// ICMP header
struct ICMPHeader 
{
    BYTE type;          // ICMP packet type
    BYTE code;          // Type sub code
    USHORT checksum;
    USHORT id;
    USHORT seq;
};

#ifdef _MSC_VER
#pragma pack()
#endif

//Declarations
extern int setup_for_ping	( char* pszHost, int ittl, SOCKET& sd, sockaddr_in& dest );
extern int send_ping		( SOCKET sd, const sockaddr_in& dest, 
								ICMPHeader* send_buf, int ipacket_size	);
extern int recv_ping		( SOCKET sd, sockaddr_in& source, IPHeader* recv_buf,
								int ipacket_size );
extern int decode_reply		( IPHeader* reply, int ibytes, sockaddr_in* from );
extern void init_ping_packet( ICMPHeader* icmp_hdr, int ipacket_size, 
								int iseq_no);
extern int Change_Counters	( int ittl, SOCKET& sd );
extern bool IsSocketReadible(SOCKET socket, unsigned long ulTimeout, bool& bReadible);
