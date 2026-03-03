module mux_4to1_using_decoder (
    input  logic [3:0] in,
    input  logic [1:0] sel,
    output logic y
);

    logic [3:0] dec_out;

    decoder_2to4 D0 (
        .sel(sel),
        .out(dec_out)
    );

    assign y = (in[0] & dec_out[0]) |
               (in[1] & dec_out[1]) |
               (in[2] & dec_out[2]) |
               (in[3] & dec_out[3]);

endmodule
