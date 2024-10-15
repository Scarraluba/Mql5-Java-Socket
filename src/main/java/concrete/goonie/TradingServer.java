package concrete.goonie;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.*;
import java.net.*;
import java.nio.*;
import java.nio.channels.*;
import java.util.*;

public class TradingServer extends JFrame {
    private static final int PORT = 12345;
    private JTextArea textArea; // For displaying messages
    private SocketChannel clientChannel; // To keep track of the connected client

    public TradingServer() {
        // Set up the GUI
        setTitle("Trading Server");
        setSize(400, 300);
        setDefaultCloseOperation(EXIT_ON_CLOSE);
        setLayout(new BorderLayout());

        textArea = new JTextArea();
        textArea.setEditable(false);
        add(new JScrollPane(textArea), BorderLayout.CENTER);

        JPanel buttonPanel = new JPanel();
        JButton sendButton = new JButton("Send Command");
        JButton connectButton = new JButton("Connect Client");

        // Add action listeners for buttons
        sendButton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                sendCommand("BUY EURUSD 1.0");
            }
        });

        connectButton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                connectClient(); // Connect to a client
            }
        });

        buttonPanel.add(sendButton);
        buttonPanel.add(connectButton);
        add(buttonPanel, BorderLayout.SOUTH);

        setVisible(true);
    }

    public static void main(String[] args) {
        TradingServer server = new TradingServer();
        server.startServer();
    }

    private void startServer() {
        try {
            Selector selector = Selector.open();
            ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
            serverSocketChannel.bind(new InetSocketAddress(PORT));
            serverSocketChannel.configureBlocking(false);
            serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);

            textArea.append("Server is listening on port " + PORT + "\n");

            while (true) {
                selector.select();
                Set<SelectionKey> selectedKeys = selector.selectedKeys();
                Iterator<SelectionKey> iterator = selectedKeys.iterator();

                while (iterator.hasNext()) {
                    SelectionKey key = iterator.next();

                    if (key.isAcceptable()) {
                        // Accept new client connections
                        clientChannel = serverSocketChannel.accept();
                        clientChannel.configureBlocking(false);
                        clientChannel.register(selector, SelectionKey.OP_READ);
                        textArea.append("New client connected: " + clientChannel.getRemoteAddress() + "\n");
                    } else if (key.isReadable()) {
                        // Handle incoming data from clients
                        handleClient(key);
                    }

                    iterator.remove(); // Remove the key from the set
                }
            }
        } catch (IOException ex) {
            textArea.append("Server exception: " + ex.getMessage() + "\n");
            ex.printStackTrace();
        }
    }

    private void connectClient() {
        // You can add any additional connection logic if necessary
        textArea.append("Connect client action initiated.\n");
    }

    private void sendCommand(String command) {
        if (clientChannel == null) {
            textArea.append("No client connected to send command.\n");
            return;
        }

        try {
            ByteBuffer buffer = ByteBuffer.allocate(256);
            buffer.put(command.getBytes());
            buffer.flip(); // Prepare buffer for writing

            while (buffer.hasRemaining()) {
                clientChannel.write(buffer); // Send command to the client
            }
            textArea.append("Sent command: " + command + "\n");
        } catch (IOException ex) {
            textArea.append("Error sending command: " + ex.getMessage() + "\n");
            ex.printStackTrace();
        }
    }

    private void handleClient(SelectionKey key) {
        SocketChannel clientChannel = (SocketChannel) key.channel();
        try {
            ByteBuffer buffer = ByteBuffer.allocate(256);
            int bytesRead = clientChannel.read(buffer);

            if (bytesRead == -1) {
                textArea.append("Client disconnected: " + clientChannel.getRemoteAddress() + "\n");
                clientChannel.close();
            } else {
                String message = new String(buffer.array(), 0, bytesRead).trim();
                textArea.append("Received from MQL5: " + message + "\n");

                // Respond back to the client
                String response = "Java processed command: " + message;
                ByteBuffer responseBuffer = ByteBuffer.allocate(256);
                responseBuffer.put(response.getBytes());
                responseBuffer.flip(); // Prepare buffer for writing

                while (responseBuffer.hasRemaining()) {
                    clientChannel.write(responseBuffer); // Send response back to the client
                }
                textArea.append("Sent to MQL5: " + response + "\n");
            }
        } catch (IOException ex) {
            textArea.append("Client communication error: " + ex.getMessage() + "\n");
            try {
                clientChannel.close();
            } catch (IOException e) {
                textArea.append("Error closing client channel: " + e.getMessage() + "\n");
            }
        }
    }
}
