#include "stdafx.h"
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iostream.h>

#include "rawping.h"
#include "ip_checksum.h"

extern bool bGlobalReset;
extern ULONG ulTimestamp;

//////////////////////////// setup_for_ping ////////////////////////////
// Creates the Winsock structures necessary for sending and recieving
// ping packets.  host can be either a dotted-quad IP address, or a
// host name.  ttl is the time to live (a.k.a. number of hops) for the
// packet.  The other two parameters are outputs from the function.
// Returns < 0 for failure.

int setup_for_ping( char* pszHost, int ittl, SOCKET& sd, sockaddr_in& dest )
{
    // Create the socket
    sd = WSASocket( AF_INET, SOCK_RAW, IPPROTO_ICMP, 0, 0, 0 );
	//check the Validity of created Socket
    if ( sd == INVALID_SOCKET ) 
	{
        cerr << "Failed to create raw socket: " << WSAGetLastError() << endl;
        return -1;
    }
	
	//This function sets a socket option.
    if ( setsockopt( sd, IPPROTO_IP, IP_TTL, ( const char* )&ittl, 
						sizeof( ittl ) ) == SOCKET_ERROR ) 
	{
        cerr << "TTL setsockopt failed: " << WSAGetLastError() << endl;
        return -1;
    }

    // Initialize the destination host info block
    memset( &dest, 0, sizeof( dest ) );

    // Turn first passed parameter into an IP address to ping
    unsigned int addr = inet_addr( pszHost );
    //if its quad Address then OK
	if ( addr != INADDR_NONE ) 
	{
        // It was a dotted quad number, so save result
        dest.sin_addr.s_addr	= addr;
        dest.sin_family			= AF_INET;
    }
    else 
	{
        // Not in dotted quad form, so try and look it up
        hostent* hp = gethostbyname( pszHost );
        if ( hp != 0 )  
		{
            // Found an address for that host, so save it
            memcpy( &(dest.sin_addr), hp->h_addr, hp->h_length );
            dest.sin_family = hp->h_addrtype;
        }
        else 
		{
            // Not a recognized hostname either!
            cerr << "Failed to resolve " << pszHost  << endl;
            return -1;
        }
    }

    return 0;
}



/////////////////////////// init_ping_packet ///////////////////////////
// Fill in the fields and data area of an ICMP packet, making it 
// packet_size bytes by padding it with a byte pattern, and giving it
// the given sequence number.  That completes the packet, so we also
// calculate the checksum for the packet and place it in the appropriate
// field.

void init_ping_packet( ICMPHeader* icmp_hdr, int ipacket_size, int iseq_no )
{
    // Set up the packet's fields
    icmp_hdr->type		= ICMP_ECHO_REQUEST;
    icmp_hdr->code		= 0;
    icmp_hdr->checksum	= 0;
    icmp_hdr->id		= (USHORT)GetCurrentProcessId();
    icmp_hdr->seq		= iseq_no;
	ulTimestamp			= GetTickCount ();//Save The Tick Count

    // "You're dead meat now, packet!"
    const unsigned long int deadmeat = 0xDEADBEEF;
    char* datapart = (char*)icmp_hdr + sizeof(ICMPHeader);
    int bytes_left = ipacket_size - sizeof(ICMPHeader);
    while (bytes_left > 0) 
	{
        memcpy(datapart, &deadmeat, min(int(sizeof(deadmeat)), bytes_left));
        bytes_left	-= sizeof(deadmeat);
        datapart	+= sizeof(deadmeat);
    }

    // Calculate a checksum on the result
    icmp_hdr->checksum = ip_checksum((USHORT*)icmp_hdr, ipacket_size);
}


/////////////////////////////// send_ping //////////////////////////////
// Send an ICMP echo ("ping") packet to host dest by way of sd with
// packet_size bytes.  packet_size is the total size of the ping packet
// to send, including the ICMP header and the payload area; it is not
// checked for sanity, so make sure that it's at least 
// sizeof(ICMPHeader) bytes, and that send_buf points to at least
// packet_size bytes.  Returns < 0 for failure.

int send_ping( SOCKET sd, const sockaddr_in& dest, 
				ICMPHeader* send_buf, int ipacket_size	)
{
  
	int bwrote = sendto( sd, ( char* )send_buf, ipacket_size, 0, 
            ( sockaddr* )&dest, sizeof( dest ) );
    if ( bwrote == SOCKET_ERROR ) 
	{
        cerr << "send failed: " << WSAGetLastError() << endl;
        return -1;
    }
    else if ( bwrote < ipacket_size ) 
	{
        cout << "sent " << bwrote << " bytes..." << flush;
    }

    return 0;
}


/////////////////////////////// recv_ping //////////////////////////////
// Receive a ping reply on sd into recv_buf, and stores address info
// for sender in source.  On failure, returns < 0, 0 otherwise.  
// 
// Note that recv_buf must be larger than send_buf (passed to send_ping)
// because the incoming packet has the IP header attached.  It can also 
// have IP options set, so it is not sufficient to make it 
// sizeof(send_buf) + sizeof(IPHeader).  We suggest just making it
// fairly large and not worrying about wasting space.

int recv_ping( SOCKET sd, sockaddr_in& source, IPHeader* recv_buf, 
				int ipacket_size)
{
    // Wait for the ping reply
    int fromlen = sizeof( source );
    int bread = recvfrom( sd, ( char* )recv_buf, ipacket_size + sizeof(IPHeader), 0,
							(sockaddr*)&source, &fromlen );
    if ( bread == SOCKET_ERROR ) 
	{
        cerr << "read failed: ";
        if (WSAGetLastError() == WSAEMSGSIZE) 
		{
            cerr << "buffer too small" << endl;
        }
        else 
		{
            cerr << "error #" << WSAGetLastError() << endl;
        }
        return -1;
    }

    return 0;
}


///////////////////////////// decode_reply /////////////////////////////
// Decode and output details about an ICMP reply packet.  Returns -1
// on failure, -2 on "try again" and 0 on success.


////////////////////////////////////////
int decode_reply( IPHeader* reply, int bytes, sockaddr_in* from ) 
{
    // Skip ahead to the ICMP header within the IP packet
    unsigned short header_len = reply->h_len * 4;
    
	ICMPHeader* icmphdr = ( ICMPHeader* )( ( char* )reply + header_len );

    // Make sure the reply is sane
    if (bytes < header_len + ICMP_MIN) 
	{
        cerr << "too few bytes from " << inet_ntoa(from->sin_addr) << endl;
        return -1;
    }
    else if ( icmphdr->type != ICMP_ECHO_REPLY ) 
	{
        if ( icmphdr->type != ICMP_TTL_EXPIRE ) 
		{
            if ( icmphdr->type == ICMP_DEST_UNREACH ) 
			{
                cerr << "Destination unreachable" << endl;
            }
            else 
			{
                cerr << "Unknown ICMP packet type " << int(icmphdr->type) <<
                        " received" << endl;
            }
            return -1;
        }
        // If "TTL expired", fall through.  Next test will fail if we
        // try it, so we need a way past it.
    }
    else if (icmphdr->id != (USHORT)GetCurrentProcessId()) 
	{
        // Must be a reply for another pinger running locally, so just
        // ignore it.
        return -2;
    }

 
    // Okay, we ran the gamut, so the packet must be legal -- dump it
    if (( icmphdr->type == ICMP_TTL_EXPIRE ) || ( icmphdr->type == ICMP_ECHO_REPLY ) ) 
	{
		in_addr in;
		in.S_un.S_addr = reply->source_ip; 
		cout << "\n Source IP " << inet_ntoa( in ) ; 
		int nTime = GetTickCount () - ulTimestamp ;
		if ( nTime < 0 )
		{
			cout << "  Time: " << "<10 ms." << endl;
		}
		else
		{
			cout << "  Time: " << ( GetTickCount() - ulTimestamp ) << " ms." << endl;
		}
    }
	if ( icmphdr->type == ICMP_ECHO_REPLY )
	{
		//we Have Reached the Destination
		bGlobalReset = true;
	}
    return 0;
}

///////////////////////Change_Counters////////////////////
int Change_Counters(int ittl, SOCKET& sd )
{
		//This function sets a socket option.
    if ( setsockopt(sd, IPPROTO_IP, IP_TTL, (const char*)&ittl, 
						sizeof(ittl)) == SOCKET_ERROR) 
	{
        cerr << "TTL setsockopt failed: " << WSAGetLastError() << endl;
        return -1;
    }
	return 0;
}
/////////////////////////
bool IsSocketReadible(SOCKET socket, unsigned long ulTimeout, bool& bReadible)
{
  timeval timeout;
  timeout.tv_sec =  ulTimeout / 1000;
  timeout.tv_usec = ulTimeout % 1000;
  fd_set fds;
  FD_ZERO(&fds);
  FD_SET(socket, &fds);
  int nStatus = select(0, &fds, NULL, NULL, &timeout);
  if (nStatus == SOCKET_ERROR)
    return FALSE;
  else
  {
    bReadible = !(nStatus == 0);
    return TRUE;
  }
}