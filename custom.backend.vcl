vcl 4.0;

backend default {
    .host = "172.31.165.162";
    .port = "80";
#    backend default {
#    .probe = {
#        .url = "/ping";
#        .timeout  = 1s;
#        .interval = 10s;
#        .window    = 5;
#        .threshold = 2;
#    }
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
}
