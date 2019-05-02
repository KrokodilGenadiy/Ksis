// TracesRoutes.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include <winsock2.h>
#include <iostream.h>
#include "stdlib.h"
#include "ExtFiles/rawping.h"

/////////////////////Definitions ///////////////////
#define DEFAULT_PACKET_SIZE		32
#define DEFAULT_TTL				30
#define MAX_PING_DATA_SIZE		1024
#define MAX_PING_PACKET_SIZE (MAX_PING_DATA_SIZE + sizeof(IPHeader))

int allocate_buffers(ICMPHeader*& send_buf, IPHeader*& recv_buf,
        int ipacket_size);


bool bGlobalReset;	  // Should We Reset? Used for ICMP_ECHO REPLY	
ULONG ulTimestamp;    // Time Stamp
///////////////////////////////
// Set up for pinging


///////////////////main ///////////////////////
int main(int argc, char* argv[])
{
    // Init some variables at top, so they aren't skipped by the
    // cleanup routines.
	int seq_no = 0;
    SOCKET sd;
	sockaddr_in dest, source;
    IPHeader	* recv_buf	= 0;
    ICMPHeader	* send_buf	= 0;
	bGlobalReset			= false;
	unsigned long ulTime	= 0; 
    // Did user pass enough parameters?
    if ( argc < 2 ) 
	{
		cerr << "usage: " << argv[0] << " <host> <timeout>" << endl;
        return 1;
    }

    // Figure out how big to make the ping packet
    int packet_size = DEFAULT_PACKET_SIZE	;
    int ttl			= DEFAULT_TTL			;
	
	if ( argc == 3 ) 
	{
		ulTime = atol( argv[ 2 ] );
	}
	else
	{
		ulTime = 2000;
	}
    // Start Winsock up
    WSAData wsaData;
    if (WSAStartup(MAKEWORD(2, 1), &wsaData) != 0) 
	{
        cerr << "Failed to find Winsock 2.1 or better." << endl;
        return 1;
    }
	
	cout << "Sending " << packet_size << " bytes to " << argv[1] << "..." << flush << endl;

	int nCounter = 1;

	
	//Sets up WinSock gets Settings of Dest in Destination
	if ( setup_for_ping( argv[1], nCounter, sd, dest ) < 0) 
	{
		goto cleanup;
	}
	//Allocates Buffers for Packets
	if ( allocate_buffers( send_buf, recv_buf, packet_size ) < 0) 
	{
		goto cleanup;
	}

	init_ping_packet( send_buf, packet_size, seq_no  );

	while (   ( nCounter < 3 ) || !(bGlobalReset) )
	{

		//cout << "Counter == " << nCounter <<  endl;
		//cout << "GLobal Reset == " << bGlobalReset << endl;
		//Change TTL
		if ( Change_Counters ( nCounter,sd  ) < 0 )
		{
			goto cleanup;
		}
		// Send the ping and receive the reply
		if ( send_ping( sd, dest, send_buf, packet_size ) >= 0 )  
		{
			while (1) 
			{
				bool bReadable=true;
				IsSocketReadible ( sd,ulTime ,bReadable);
				if ( bReadable )
				{
					// Receive replies until we either get a successful read,
					// or a fatal error occurs.
					if ( recv_ping( sd, source, recv_buf, MAX_PING_PACKET_SIZE ) < 0 ) 
					{
						// Pull the sequence number out of the ICMP header.  If 
						// it's bad, we just complain, but otherwise we take 
						// off, because the read failed for some reason.
						unsigned short header_len = recv_buf->h_len * 4;
						ICMPHeader* icmphdr = (ICMPHeader*)((char*)recv_buf + header_len);
						if ( icmphdr->seq != seq_no ) 
						{
							cerr << "bad sequence number!" << endl;
							continue;
						}
						else 
						{
							break;
						}
					}
					int nRet =decode_reply ( recv_buf, packet_size, &source ) ;
					if ( nRet == -1 )
					{
						goto cleanup;
					}
					if (  nRet != -2)
					{
						// Success or fatal error (as opposed to a minor error) 
						// so take off.
						break;
					}

				}
				else
				{
					cout << "Request Time Out\n" << endl;
					break;
				}
				

			
			}
			// there Should be a Better way!!
			if ( nCounter == 10 )
			{
				bGlobalReset = true;
			}
		}


		nCounter++;
		
	}
cleanup:
	delete[] send_buf;
	delete[] recv_buf;		
	WSACleanup();
	return 0;

}

/////////////////////////// allocate_buffers ///////////////////////////
// Allocates send and receive buffers.  Returns < 0 for failure.

int allocate_buffers( ICMPHeader*& send_buf, IPHeader*& recv_buf,
						int ipacket_size )
{
    // First the send buffer
    send_buf = (ICMPHeader*)new char[ipacket_size];  
    
	if ( send_buf == 0 ) 
	{
        cerr << "Failed to allocate output buffer." << endl;
        return -1;
    }

    // And then the receive buffer
    recv_buf = (IPHeader*)new char[MAX_PING_PACKET_SIZE];
    if ( recv_buf == 0 ) 
	{
        cerr << "Failed to allocate output buffer." << endl;
        return -1;
    }
    
    return 0;
}
