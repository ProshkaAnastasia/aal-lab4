module cordic_atan2_pipe (
    input  wire clk,
    input  wire rst,
    input  wire in_valid,
    input  wire signed [31:0] x_in,
    input  wire signed [31:0] y_in,
    output wire out_valid,
    output wire signed [31:0] angle_out
);
    localparam integer STAGES = 32;
    localparam signed [33:0] PI     = 34'sd1686629713;
    localparam signed [33:0] TWO_PI = 34'sd3373259426;

    function automatic signed [33:0] atan_const(input integer i);
        case (i)
             0: atan_const = 34'sd421657428;
             1: atan_const = 34'sd248918915;
             2: atan_const = 34'sd131521918;
             3: atan_const = 34'sd66762579;
             4: atan_const = 34'sd33510843;
             5: atan_const = 34'sd16771758;
             6: atan_const = 34'sd8387925;
             7: atan_const = 34'sd4194219;
             8: atan_const = 34'sd2097141;
             9: atan_const = 34'sd1048575;
            10: atan_const = 34'sd524288;
            11: atan_const = 34'sd262144;
            12: atan_const = 34'sd131072;
            13: atan_const = 34'sd65536;
            14: atan_const = 34'sd32768;
            15: atan_const = 34'sd16384;
            16: atan_const = 34'sd8192;
            17: atan_const = 34'sd4096;
            18: atan_const = 34'sd2048;
            19: atan_const = 34'sd1024;
            20: atan_const = 34'sd512;
            21: atan_const = 34'sd256;
            22: atan_const = 34'sd128;
            23: atan_const = 34'sd64;
            24: atan_const = 34'sd32;
            25: atan_const = 34'sd16;
            26: atan_const = 34'sd8;
            27: atan_const = 34'sd4;
            28: atan_const = 34'sd2;
            29: atan_const = 34'sd1;
            default: atan_const = 34'sd0;
        endcase
    endfunction

    reg signed [33:0] x     [0:STAGES];
    reg signed [33:0] y     [0:STAGES];
    reg signed [33:0] angle [0:STAGES];
    reg [STAGES:0] valid, zero_vector;

    wire signed [33:0] x_ext = {{2{x_in[31]}}, x_in};
    wire signed [33:0] y_ext = {{2{y_in[31]}}, y_in};

    always @(posedge clk) begin
        if (rst)
            valid[0] <= 1'b0;
        else
            valid[0] <= in_valid;

        x[0] <= x_in[31] ? -x_ext : x_ext;
        y[0] <= x_in[31] ? -y_ext : y_ext;
        angle[0] <= x_in[31] ? PI : 34'sd0;
        zero_vector[0] <= (x_in == 0 && y_in == 0);
    end

    for (genvar i = 0; i < STAGES; i = i + 1) begin : rotation
        localparam signed [33:0] STEP_ANGLE = atan_const(i);
        wire signed [33:0] shifted_x = x[i] >>> i;
        wire signed [33:0] shifted_y = y[i] >>> i;

        always @(posedge clk) begin
            if (rst)
                valid[i+1] <= 1'b0;
            else
                valid[i+1] <= valid[i];

            zero_vector[i+1] <= zero_vector[i];

            if (y[i] > 34'sd0) begin
                x[i+1]     <= x[i] + shifted_y;
                y[i+1]     <= y[i] - shifted_x;
                angle[i+1] <= angle[i] + STEP_ANGLE;
            end else begin
                x[i+1]     <= x[i] - shifted_y;
                y[i+1]     <= y[i] + shifted_x;
                angle[i+1] <= angle[i] - STEP_ANGLE;
            end
        end
    end

    wire signed [33:0] raw_angle = angle[STAGES];
    wire signed [33:0] normalized =
        raw_angle >  PI ? raw_angle - TWO_PI :
        raw_angle < -PI ? raw_angle + TWO_PI : raw_angle;

    assign out_valid = valid[STAGES];
    assign angle_out = zero_vector[STAGES] ? 32'sd0 : normalized[31:0];
endmodule