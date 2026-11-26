module cordic_atan2_csr (
    input  wire clk,
    input  wire rst,
    input  wire req,
    input  wire we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg resp,
    output reg [31:0] rdata
);
    localparam [31:0] X_ADDR      = 32'h10000000;
    localparam [31:0] Y_ADDR      = 32'h10000004;
    localparam [31:0] STATUS_ADDR = 32'h10000008;
    localparam [31:0] ANGLE_ADDR  = 32'h1000000c;

    reg [31:0] x_arg, y_arg, result;
    reg busy, done;

    wire start = req && we && addr == STATUS_ADDR && wdata[0] && !busy;
    wire result_valid;
    wire [31:0] result_angle;

    cordic_atan2_pipe core (
        .clk(clk),
        .rst(rst),
        .in_valid(start),
        .x_in(x_arg),
        .y_in(y_arg),
        .out_valid(result_valid),
        .angle_out(result_angle)
    );

    always @(posedge clk) begin
        resp <= 1'b0;

        if (rst) begin
            x_arg  <= 0;
            y_arg  <= 0;
            result <= 0;
            busy   <= 1'b0;
            done   <= 1'b0;
            rdata  <= 0;
        end else begin
            if (start) begin
                busy <= 1'b1;
                done <= 1'b0;
            end

            if (result_valid) begin
                result <= result_angle;
                busy   <= 1'b0;
                done   <= 1'b1;
            end

            if (req && we) begin
                case (addr)
                    X_ADDR: x_arg <= wdata;
                    Y_ADDR: y_arg <= wdata;
                    default: ;
                endcase
            end

            if (req && !we) begin
                resp <= addr == X_ADDR || addr == Y_ADDR ||
                        addr == STATUS_ADDR || addr == ANGLE_ADDR;

                case (addr)
                    X_ADDR:      rdata <= x_arg;
                    Y_ADDR:      rdata <= y_arg;
                    STATUS_ADDR: rdata <= {30'b0, busy, done};
                    ANGLE_ADDR:  rdata <= result;
                    default:     rdata <= 0;
                endcase
            end
        end
    end
endmodule