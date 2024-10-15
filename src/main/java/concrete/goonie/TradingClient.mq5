//+------------------------------------------------------------------+
//|                       TradingClient.mq5                          |
//|                        Copyright 2024, Your Name                 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2000-2024, Your Name"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property description "Trading client for communication with Java server"

input string ServerIP = "127.0.0.1"; // Change to your Java server IP if needed
input int ServerPort = 12345; // Java server listening port

#include <ABCD\chartObjects.mqh>

int socket;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
  {
   socket = SocketCreate(); // Create socket
   SetNewBack();
   createButton("SendCommand", 1, 1, 120, 28, "Send Command", false, 10, clrLightSlateGray, clrLightSlateGray, clrWhiteSmoke);

   socket = SocketCreate(); // Create socket
   if(socket != INVALID_HANDLE)
     {
      // Try to connect to the Java server
      if(SocketConnect(socket, ServerIP, ServerPort, 1000))
        {
         Print("Established connection to ", ServerIP, ":", ServerPort);
         return INIT_SUCCEEDED;// Proceed with initialization (create buttons, etc.)
        }
      else
        {
         Print("Connection to ", ServerIP, ":", ServerPort, " failed, error ", GetLastError());
         return INIT_FAILED; // Initialization failed
        }
     }
   else
     {
      Print("Failed to create a socket, error ", GetLastError());
      return INIT_FAILED; // Initialization failed
     }
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(socket != INVALID_HANDLE)
     {
      SocketClose(socket); // Close the socket when the EA is removed
     }
  }
//+------------------------------------------------------------------+
//| Send all positions to the Java server                             |
//+------------------------------------------------------------------+
void SendAllPositions() {
    string positions = "";
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetTicket(i)) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
            double profit = PositionGetDouble(POSITION_PROFIT);
            // Format: Symbol;Volume;PriceOpen;Profit
            positions += StringFormat("%s;%.2f;%.5f;%.2f\n", symbol, volume, priceOpen, profit);
        }
    }

    if (positions != "") {
        if (SendCommand( "POSITIONS\n" + positions)) {
            Print("Sent all positions to Java server.");
        } else {
            Print("Failed to send positions.");
        }
    } else {
        Print("No positions to send.");
    }
}
//+------------------------------------------------------------------+
//| Main loop for continuous communication                             |
//+------------------------------------------------------------------+
void OnTick()
  {

// Check for incoming messages from the Java server
   if(ReceiveResponse(1000))
     {
      // If you want to react to the message, add your handling logic here
      // e.g., execute trade based on the response received.
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {

   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == "SendCommand")
        {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
         double open = iOpen("EURUSD", 0, 0);  // Current open price
         double high = iHigh("EURUSD", 0, 0);  // Current high price
         double low = iLow("EURUSD", 0, 0);    // Current low price
         double close = iClose("EURUSD", 0, 0); // Current close price

         // Construct the candlestick message
         string candleMessage = StringFormat("CANDLE EURUSD OPEN:%.5f HIGH:%.5f LOW:%.5f CLOSE:%.5f", open, high, low, close);

       SendAllPositions();

         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Send command to the Java server                                   |
//+------------------------------------------------------------------+
bool SendCommand(string command)
  {
   char req[];
   int len = StringToCharArray(command, req) - 1; // Convert string to char array
   if(len < 0)
      return false; // Check for valid length

// Send the command through the socket
   if(SocketSend(socket, req, len) == len)
     {
      Print("Sent command: ", command);
      return true;
     }
   else
     {
      Print("Failed to send command, error: ", GetLastError());
      return false;
     }
  }

//+------------------------------------------------------------------+
//| Read response from the Java server                                |
//+------------------------------------------------------------------+
bool ReceiveResponse(uint timeout)
  {
   char responseBuffer[1024]; // Buffer for response
   string response = "";
   uint timeout_check = GetTickCount() + timeout;

// Read data until there's no more data or timeout occurs
   do
     {
      uint len = SocketIsReadable(socket);
      if(len)
        {
         int bytesRead = SocketRead(socket, responseBuffer, len, timeout);
         if(bytesRead > 0)
           {
            response += CharArrayToString(responseBuffer, 0, bytesRead);
           }
         else
           {
            // No more data available
            break;
           }
        }
     }
   while(GetTickCount() < timeout_check && !IsStopped());

   if(StringLen(response) > 0)
     {
      Print("Received response: ", response);
      return true; // Response received successfully
     }
   else
     {

      return false; // No response received
     }
  }
//+------------------------------------------------------------------+
