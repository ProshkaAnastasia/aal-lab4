`timescale 1ns / 1ps

module tb_cordic_inline;
    localparam integer LATENCY = 32;
    localparam MEM_FILE = "C:/Users/grosb/Vivado/aal-lab4/activecore-master/designs/rtl/udm/syn/NEXYS4_DDR/NEXYS4_DDR.srcs/sim_1/new/cordic_vectors.mem";

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst = 1'b1;
    reg in_valid = 1'b0;
    reg signed [31:0] x_in = 0;
    reg signed [31:0] y_in = 0;
    reg [31:0] expected_in = 0;

    wire out_valid;
    wire signed [31:0] angle_out;

    reg [LATENCY:0] valid_history = 0;
    reg [31:0] expected_history [0:LATENCY];
    integer checked = 0;

    cordic_atan2_pipe dut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .x_in(x_in),
        .y_in(y_in),
        .out_valid(out_valid),
        .angle_out(angle_out)
    );

    // Сопоставляем каждый выход с эталоном, поданным 32 такта назад.
    always @(posedge clk) begin
        if (rst)
            valid_history = 0;
        else
            valid_history = {valid_history[LATENCY-1:0], in_valid};

        for (integer i = LATENCY; i > 0; i = i - 1)
            expected_history[i] = expected_history[i-1];

        expected_history[0] = expected_in;

        // Ждём обновления регистров ядра после фронта.
        #1;
        if (out_valid !== valid_history[LATENCY])
            $fatal(1, "Unexpected out_valid at time %0t: expected=%b got=%b",
                   $time, valid_history[LATENCY], out_valid);

        if (out_valid) begin
            if (angle_out !== expected_history[LATENCY])
                $fatal(1, "Vector %0d: expected=%08h got=%08h",
                       checked + 1, expected_history[LATENCY], angle_out);

            checked = checked + 1;
        end
    end

    initial begin : run_vectors
        integer mem_fd;
        integer read_status;
        integer sent;
        string token;
        reg [95:0] vector_word;

        sent = 0;
        mem_fd = $fopen(MEM_FILE, "r");

        if (mem_fd == 0)
            $fatal(1, "Cannot open MEM file: %s", MEM_FILE);

        repeat (3) @(negedge clk);
        rst = 1'b0;

        // Слова могут быть разделены пробелами или переносами строк.
        read_status = $fscanf(mem_fd, "%s", token);

        while (read_status == 1) begin
            if (token.len() != 24)
                $fatal(1, "Vector %0d: expected 24 hex digits, got '%s'",
                       sent + 1, token);

            for (integer i = 0; i < token.len(); i = i + 1) begin
                if (!((token[i] >= 8'h30 && token[i] <= 8'h39) ||
                      (token[i] >= 8'h41 && token[i] <= 8'h46) ||
                      (token[i] >= 8'h61 && token[i] <= 8'h66)))
                    $fatal(1, "Vector %0d: invalid hex word '%s'",
                           sent + 1, token);
            end

            if ($sscanf(token, "%h", vector_word) != 1)
                $fatal(1, "Vector %0d: cannot parse '%s'", sent + 1, token);

            @(negedge clk);
            // [95:64] = X, [63:32] = Y, [31:0] = угол из модели.
            {x_in, y_in, expected_in} = vector_word;
            in_valid = 1'b1;
            sent = sent + 1;

            read_status = $fscanf(mem_fd, "%s", token);
        end

        if (read_status != -1)
            $fatal(1, "Error reading %s after %0d vectors", MEM_FILE, sent);

        $fclose(mem_fd);

        if (sent == 0)
            $fatal(1, "No vectors found in %s", MEM_FILE);

        @(negedge clk);
        in_valid = 1'b0;

        // Дожидаемся выхода последней пары из конвейера.
        repeat (LATENCY + 2) @(negedge clk);

        if (checked != sent)
            $fatal(1, "Sent %0d vectors, checked %0d results", sent, checked);

        $display("PASS: %0d bit-exact results, latency = %0d cycles, II = 1",
                 checked, LATENCY);
        $finish;
    end
endmodule