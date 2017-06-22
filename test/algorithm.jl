@testset "Solving algorithm tests" begin
    @testset " Validation Test || ATMC || basic solve || exampls/nlp1.jl" begin

        # This test's ans come from old DTMC code
        m = nlp1()
        setsolver = (m, PODSolver(nlp_local_solver=IpoptSolver(),
                                   mip_solver=GurobiSolver(OutputFlag=0),
                                   presolve_perform_bound_tightening=false,
                                   presolve_bound_tightening_algo=1,
                                   presolve_bt_output_tolerance=1e-1,
                                   log_level=0))
        status = solve(m)

        @test status == :Optimal
        @test isapprox(m.objVal, 58.38367169858795; atol=1e-4)
        @test m.internalModel.logs[:n_iter] == 7

        @test isapprox(m.internalModel.logs[:obj][1], 58.38367118523376; atol=1e-3)
        @test isapprox(m.internalModel.logs[:obj][2], 58.38367118523376; atol=1e-3)
        @test isapprox(m.internalModel.logs[:obj][3], 58.38367118523376; atol=1e-3)
        @test isapprox(m.internalModel.logs[:obj][4], 58.38367118523376; atol=1e-3)
        @test isapprox(m.internalModel.logs[:obj][5], 58.38367118523376; atol=1e-3)
        @test isapprox(m.internalModel.logs[:obj][6], 58.38367118523376; atol=1e-3)
        @test isapprox(m.internalModel.logs[:obj][7], 58.38367118523376; atol=1e-3)

        @test isapprox(m.internalModel.logs[:bound][1], 25.7091; atol=1e-3)
        @test isapprox(m.internalModel.logs[:bound][2], 51.5131; atol=1e-3)
        @test isapprox(m.internalModel.logs[:bound][3], 56.5857; atol=1e-3)
        @test isapprox(m.internalModel.logs[:bound][4], 58.2394; atol=1e-3)
        @test isapprox(m.internalModel.logs[:bound][5], 58.3644; atol=1e-3)
        @test isapprox(m.internalModel.logs[:bound][6], 58.3686; atol=1e-3)
        @test isapprox(m.internalModel.logs[:bound][7], 58.3832; atol=1e-3)

        # Also check active partitions
        # Also check small partitions

        # Testing discretizations for x1 and x2
        ans = Dict()
        ans[1] = [1.0,1.12035,2.10076,2.43359,2.51991,2.52774,2.55118,2.60884,2.64305,2.75053,2.89483,3.02324,4.80577, 10.0]
        ans[2] = [1.0,1.13852,2.26689,2.64995,2.89107,3.02633,3.06707,3.13215,3.15649,3.18081,3.3286,5.38017, 10.0]

        @test length(ans[1]) == length(m.internalModel.discretization[1])
        @test length(ans[2]) == length(m.internalModel.discretization[2])
        for i in 1:length(ans[1])
            @test isapprox(ans[1][i], m.internalModel.discretization[1][i]; atol=1e-1)
        end
        for i in 1:length(ans[2])
            @test isapprox(ans[2][i], m.internalModel.discretization[2][i]; atol=1e-1)
        end
    end

    @testset " Validation Test || ATMC || basic solve || examples/nlp3.jl (40s)" begin
        # This test ans is base on old DTMC code
        m = nlp3()
        setsolver(m, solver=PODSolver(nlp_local_solver=IpoptSolver(print_level=0),
                					   mip_solver=CbcSolver(),
                					   log_level=0,
                                       max_iter=4,
                                       tolerance=1e-5,
                					   presolve_bt_width_tolerance=1e-3,
                					   presolve_perform_bound_tightening=false,
                                       presolve_bound_tightening_algo=2,
                					   discretization_var_pick_algo=0))
        stats = solve(m)

        @test status == :UserLimits

        @test isapprox(m.objVal, 7049.247897696512; atol=1e-4)
        @test m.internalModel.logs[:n_iter] == 4

        @test isapprox(m.internalModel.logs[:obj][1], 7049.247897696513; atol=1e-3)
        @test isapprox(m.internalModel.logs[:obj][2], 7049.247897696513; atol=1e-3)
        @test isapprox(m.internalModel.logs[:obj][3], 7049.247897696513; atol=1e-3)
        @test isapprox(m.internalModel.logs[:obj][4], 7049.247897696513; atol=1e-3)

        @test isapprox(m.internalModel.logs[:bound][1], 3004.2470; atol=1e-3)
        @test isapprox(m.internalModel.logs[:bound][2], 4896.6075; atol=1e-3)
        @test isapprox(m.internalModel.logs[:bound][3], 5871.5306; atol=1e-3)
        @test isapprox(m.internalModel.logs[:bound][4], 6717.2923; atol=1e-3)

        ans = Dict()
        ans[1] = [100.0,467.809,475.693,661.077,838.577,3054.31,10000.0]
        ans[2] = [1000.0,1352.39,1413.05,1606.7,1739.7,3609.97,10000.0]
        ans[3] = [1000.0,1352.05,2282.04,2859.97,3365.52,4221.02,4570.98,7359.97,10000.0]
        ans[4] = [10.0,16.5493,126.38,160.694,210.658,226.308,429.518,1000.0]
        ans[5] = [10.0,48.1012,141.794,242.271,278.835,340.71,366.021,389.294,543.101,1000.0]
        ans[6] = [10.0,164.701,185.971,242.678,278.115,392.442,465.482,1000.0]
        ans[7] = [10.0,38.9165,132.135,212.799,244.965,306.84,336.549,379.635,533.917,1000.0]
        ans[8] = [10.0,148.101,241.794,342.271,378.835,440.71,466.021,489.294,643.101,1000.0]

        for i in 1:8
            for j in 1:length(ans[i])
                @test length(ans[i]) == length(m.internalModel.discretization[i])
                @test isapprox(ans[i][j], m.internalModel.discretization[i][j]; atol=1e-1)
            end
        end
    end

    @testset " Algorithm Test || ATMC || basic solve || examples/castro02m2.jl" begin
        m = castro02m2()
        solve(m)

        @test isapprox(m.objVal, 130.70551417755; atol=1e-4)
        @test m.internalModel.logs[:n_iter] == 12

        objs = [470.317,130.706,130.706,130.706,130.706,130.706,130.706,130.706,130.706,130.706,130.706,130.706,130.706]
        bounds = [78.0,78.0,78.0,78.1349,79.151,100.48,115.081,129.075,129.794,130.058,130.405,130.608]

        for i in 1:m.internalModel.logs[:n_iter]
            @test isapprox(m.internalModel.logs[:obj][i], objs[i]; atol=1e-3)
            @test isapprox(m.internalModel.logs[:bound][i], bounds[i]; atol=1e-3)
        end

        discretizations = Dict(18 => [0.0,1.0e6],
                  30 => [0.0,0.0604439,0.241776,0.967103,3.86841,15.4736,61.8946,245.473,977.894,3907.58,15626.3,62501.2,2.50000e5,1.0e6],
                  33 => [0.0,0.0697542,0.279017,1.11607,4.46427,16.1874,62.1518,245.316,977.557,3906.31,15625.1,62500.1,2.5e5,1.0e6],
                  32 => [0.0,0.390791,0.643519,1.13844,1.38062,1.97967,4.35491,15.5086,61.094,244.141,976.565,3906.26,15625.0,62500.2,2.50000e5,1.0e6],
                  41 => [0.0,1.0e6],
                  2  => [0.0,1.0e6],
                  40 => [0.0,1.0e6],
                  16 => [0.0,1.0e6],
                  11 => [0.0,1.0e6],
                  21 => [0.0,1.0e6],
                  39 => [0.0,1.0e6],
                  7  => [0.0,1.0e6],
                  9  => [0.0,1.0e6],
                  25 => [0.0,1.0e6],
                  10 => [0.0,1.0e6],
                  26 => [0.0,1.0e6],
                  29 => [0.0,2769.85,5377.55,5995.2,6104.52,6249.39,6284.92,6334.09,6401.54,6984.0,7449.84,8042.46,11557.5,13315.1,16830.2,28120.6,73282.5,2.5393e5,1.0e6],
                  34 => [0.0,1.0e6],
                  35 => [0.0,1.0e6],
                  19 => [0.0,1.0e6],
                  17 => [0.0,1.0e6],
                  42 => [-Inf,Inf],
                  8  => [0.0,1.0e6],
                  22 => [0.0,1.0e6],
                  6  => [0.0,1.0e6],
                  24 => [0.0,1.0e6],
                  4  => [0.0,1.0e6],
                  37 => [0.0,0.0117862,0.20626,0.388947,1.09862,3.95825,15.4137,61.1929,244.298,976.897,3907.51,15626.2,62501.0,250000.0,1.0e6],
                  3  => [0.0,1.0e6],
                  28 => [0.0,16.1101,94.9982,138.296,141.503,144.855,147.625,150.539,167.734,244.372,977.489,3909.96,15639.8,62559.3,2.50237e5,1.0e6],
                  5  => [0.0,1.0e6],
                  38 => [0.0,1.0e6],
                  20 => [0.0,1.0e6],
                  23 => [0.0,1.0e6],
                  13 => [0.0,1.0e6],
                  14 => [0.0,37.8378,58.1401,65.356,69.1652,71.6344,74.7512,75.3988,77.8232,83.0746,87.7069,99.7381,244.546,978.185,3912.74,15651.0,62603.8,2.50415e5,1.0e6],
                  31 => [0.0,0.0613609,0.245444,0.981775,3.9271,15.7084,61.3511,244.141,976.563,3906.25,15625.0,62500.0,250000.0,1.0e6],
                  27 => [0.0,1.0e6],
                  36 => [0.0,0.438631,0.719315,1.28068,1.56137,2.24548,4.98191,15.9276,61.1931,244.141,976.563,3906.25,15625.0,62500.0,2.5e5,1.0e6],
                  15 => [0.0,15.0089,39.8183,48.8791,53.1131,54.8807,59.5431,62.4379,67.5288,77.1177,89.6076,149.198,349.278,1080.51,4009.49,15725.9,62591.8,2.50055e5,1.0e6],
                  12 => [0.0,1.0e6],
                  1  => [0.0,1.0e6])

        for i in m.internalModel.var_discretization_mip
            for j in 1:length(discretizations[i])
                @test length(discretizations[i]) == length(m.internalModel.discretization[i])
                @test isapprox(discretizations[i][j], m.internalModel.discretization[i][j]; atol=1)
            end
        end
    end

    @testset " Validation Test || BT || basic solve || examples/nlp1.jl " begin
        m = nlp1()
        setsolver = (m, PODSolver(nlp_local_solver=IpoptSolver(),
                                   mip_solver=GurobiSolver(OutputFlag=0),
                                   presolve_perform_bound_tightening=true,
                                   presolve_bound_tightening_algo=1,
                                   presolve_bt_output_tolerance=1e-1,
                                   log_level=0))
        status = solve(m)
        @test status = :Optimal
        @test m.internalModel.logs[:n_iter] == 3
        @test isapprox(m.internalModel.l_var_orig[1], 2.4; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[2], 3.0; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[3], 5.76; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[4], 9.0; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[5], 7.2; atol=1e-2)

        @test isapprox(m.internalModel.u_var_orig[1], 2.7; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[2], 3.3; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[3], 7.29; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[4], 10.89; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 8.91; atol=1e-2)
    end

    @testset " Validation Test || TMC-BT || basic solve || exampls/nlp1.jl" begin
        m = nlp1()
        setsolver = (m, PODSolver(nlp_local_solver=IpoptSolver(),
    							   mip_solver=GurobiSolver(OutputFlag=0),
    							   presolve_perform_bound_tightening=true,
    							   presolve_bound_tightening_algo=2,
                                   presolve_bt_output_tolerance=1e-1,
    							   log_level=0))
        status = solve(m)

        @test status == :Optimal
        @test m.internalModel.logs[:n_iter] == 1
        @test isapprox(m.internalModel.l_var_orig[1], 2.5; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[2], 3.1; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[3], 6.25; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[4], 9.61; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[5], 7.75; atol=1e-2)

        @test isapprox(m.internalModel.u_var_orig[1], 2.6; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[2], 3.2; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[3], 6.76; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[4], 10.24; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 8.32; atol=1e-2)
    end

    @testset " Validation Test || BT || basic solve || examples/nlp3.jl" begin
        m = nlp3()
        setsolver(m, PODSolver(nlp_local_solver=IpoptSolver(print_level=0),
    							   mip_solver=GurobiSolver(OutputFlag=0),
    							   log_level=0, maxiter=4,
    							   presolve_bt_width_tolerance=1e-3,
    							   presolve_bt_output_tolerance=1e-1,
    							   presolve_perform_bound_tightening=true,
                                   presolve_bound_tightening_algo=1,
    							   presolve_maxiter=2,
    							   discretization_var_pick_algo=max_cover_var_picker))

        status = solve(m)
        @test status == :UserLimits
        @test m.internalModel.logs[:n_iter] == 4
        @test m.internalModel.logs[:bt_iter] == 2

        @test isapprox(m.internalModel.l_var_orig[1], 4644.8; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[2], 5638.9; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[3], 5920.4; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[4], 334.8; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[5], 591.7; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[6], 390.0; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[7], 627.0; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[8], 691.7; atol=1e-2)

        @test isapprox(m.internalModel.u_var_orig[1], 100.0; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[2], 1000.0; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[3], 1000.0; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[4], 19,9; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 107.7; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 10.0; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 16.9; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 87.2; atol=1e-2)
    end

    @testset " Validation Test || BT || basic solve || examples/nlp3.jl" begin
        m = nlp3()
        setsolver(m, PODSolver(nlp_local_solver=IpoptSolver(print_level=0),
                                   mip_solver=GurobiSolver(OutputFlag=0),
                                   log_level=0, maxiter=4,
                                   presolve_bt_width_tolerance=1e-3,
                                   presolve_bt_output_tolerance=1e-1,
                                   presolve_perform_bound_tightening=true,
                                   presolve_bound_tightening_algo=2,
                                   presolve_maxiter=3,
                                   discretization_var_pick_algo=max_cover_var_picker))

        status = solve(m)
        @test status == :UserLimits
        @test m.internalModel.logs[:n_iter] == 4
        @test m.internalModel.logs[:bt_iter] == 3

        @test isapprox(m.internalModel.l_var_orig[1], 2187.9; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[2], 3756.6; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[3], 5784.8; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[4], 256.6; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[5], 375.4; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[6], 355.7; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[7], 351.0; atol=1e-2)
        @test isapprox(m.internalModel.l_var_orig[8], 475.4; atol=1e-2)

        @test isapprox(m.internalModel.u_var_orig[1], 100.0; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[2], 1000.0; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[3], 2710.4; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[4], 44.3; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 266.0; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 10.0; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 164.5; atol=1e-2)
        @test isapprox(m.internalModel.u_var_orig[5], 366.0; atol=1e-2)
    end
end
