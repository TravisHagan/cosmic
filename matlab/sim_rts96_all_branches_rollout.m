%% Rollout policy simulation file
clear all; close all; clc;

t_cont = 5;             % When the contingency should occur
t_rollout = 10;         % When the rollout policy begins
t_max = 30;             % Simulation end time
time_step = 1/60;       % Time step for rollout policy

if ~(ismcc || isdeployed)
    addpath('../data');
    addpath('../numerics');
end

C = psconstants;
opt = psoptions;

load('rts96.mat','ps');

%% Output file:

opt.sim.use_data_correction = true;

results = cell(length(ps.branch(:,1)),4);         % Allocate cell matrix

output_file = sprintf('sim_rts96_%s', datestr(now,'yyyy-mm-dd_HHMMSS'));

results_struct.begin_time = datestr(now);
results_struct.t_max = t_max;
results_struct.data_correction = opt.sim.use_data_correction;


%%
for k = 1:length(ps.branch(:,1))
    results{k,1} = ps.branch(k, C.br.from);
    results{k,2} = ps.branch(k, C.br.to);
    results{k,3} = ps.branch(k, C.br.id);
    load('rts96.mat','ps')
    
    fprintf('****************************************\n')
    fprintf('       New simulation beginning         \n')
    fprintf('       Line to trip: %d to %d           \n',ps.branch(k,1),ps.branch(k,2))
    fprintf('****************************************\n')
    
    % to differentiate the line MVA ratings
    rateB_rateA = ps.branch(:,C.br.rateB)./ps.branch(:,C.br.rateA);
    rateC_rateA = ps.branch(:,C.br.rateC)./ps.branch(:,C.br.rateA);
    ps.branch(rateB_rateA == 1,C.br.rateB) = 1.1*ps.branch(rateB_rateA == 1,C.br.rateA);
    ps.branch(rateC_rateA == 1,C.br.rateC) = 1.5*ps.branch(rateC_rateA == 1,C.br.rateA);
    
    % set some options
    opt.sim.integration_scheme      = 1;
    opt.sim.dt_default              = 1/10;
    opt.nr.use_fsolve               = true;
    % opt.pf.linesearch             = 'cubic_spline';
    opt.verbose                     = false;
    opt.sim.gen_control = 1;        % 0 = generator without exciter and governor, 1 = generator with exciter and governor
    opt.sim.angle_ref = 0;          % 0 = delta_sys, 1 = center of inertia---delta_coi
                                    % Center of inertia doesn't work when having islanding
    opt.sim.COI_weight = 0;         % 1 = machine inertia, 0 = machine MVA base(Powerworld)
    opt.sim.uvls_tdelay_ini = 0.5;  % 1 sec delay for uvls relay.
    opt.sim.ufls_tdelay_ini = 0.5;  % 1 sec delay for ufls relay.
    opt.sim.dist_tdelay_ini = 0.5;  % 1 sec delay for dist relay.
    opt.sim.temp_tdelay_ini = 1e6;    % 0 sec delay for temp relay.
    opt.sim.writelog = false;
    % Don't forget to change this value (opt.sim.time_delay_ini) in solve_dae.m

    opt.sim.var_step = 0.1;
    opt.sim.dt_max_default = 0.1;


    % ps = unify_generators(ps);
    % ps.branch(:,C.br.tap)       = 1;
    % ps.shunt(:,C.sh.factor)     = 1;    % C.sh.factor is the same as C.sh.status
    ps.shunt(:,C.sh.status)     = 1;
    ps.shunt(:,C.sh.frac_S)     = 1;
    ps.shunt(:,C.sh.frac_E)     = 0;
    ps.shunt(:,C.sh.frac_Z)     = 0;
    ps.shunt(:,C.sh.gamma)      = 0.08;
    
    %% Initialize the case
    [ps, ~, ~] = newpf(ps,opt);
    
    [ps.Ybus, ps.Yf, ps.Yt] = getYbus(ps,false);
    ps = update_load_freq_source(ps);       % Set bus freq source (nearest gen)
    
    % Machine variables
    [ps.mac, ps.exc, ps.gov] = get_mac_state(ps, 'salient');
    
    % Initialize relays
    ps.relay = get_relays(ps, 'all', opt);
    
    % Initialize global variables
    global t_delay t_prev_check dist2threshold state_a;
    n                       = size(ps.bus, 1);
    ng                      = size(ps.mac, 1);
    m                       = size(ps.branch, 1);
    n_sh                    = size(ps.shunt, 1);
    ix                      = get_indices(n, ng, m, n_sh, opt);
    t_delay                 = inf(size(ps.relay, 1), 1);
    t_delay([ix.re.uvls])   = opt.sim.uvls_tdelay_ini;
    t_delay([ix.re.ufls])   = opt.sim.ufls_tdelay_ini;
    t_delay([ix.re.dist])   = opt.sim.dist_tdelay_ini;
    t_delay([ix.re.temp])   = opt.sim.temp_tdelay_ini;
    t_prev_check            = nan(size(ps.relay, 1), 1);
    dist2threshold          = inf(size(ix.re.oc, 2)*2, 1);
    state_a                 = zeros(size(ix.re.oc, 2)*2, 1);
    
    
    %% Build an event matrix
    event = zeros(3, C.ev.cols);
    
    % start
    event(1,[C.ev.time C.ev.type]) = [0 C.ev.start];
    
    % trip a branch
    event(2,[C.ev.time C.ev.type]) = [t_cont C.ev.trip_branch];
    event(2, C.ev.branch_loc) = ps.branch(k, C.br.id);
    
    % set the end time
    event(3,[C.ev.time C.ev.type]) = [t_rollout C.ev.finish];


    %% run the simulation
    [~,ps,x,y] = simgrid(ps,event,'sim_rts96',opt);
    
    save_sim_state(ps,x,y,'save_state');

    results{k,4} = RolloutPolicy(ps, opt, C, time_step, (t_max-t_rollout), 'save_state');
    
    % Take some action and continue simulation...
    % Implement later
    
            
end

results_struct.end_time = datestr(now);
results_struct.calculations = results;

save(output_file,'results_struct');




