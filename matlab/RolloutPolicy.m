function results = RolloutPolicy(ps, opt, C, time_step, t_max, save_file)
% Summary of this function goes here
%   Detailed explanation goes here
% Based on Carter Lasseter's Python based system for PSSE
%
% Only configured for constant power loads (P).
%
% Results matrix columns: 'bus number of load', 'shed percentage',
% 'reward', 'status (0 indicates blackout)'



%% Notes:
% Do not use the ps.bus.Pd or similar values. These are not used by the
% program
%
% C.sh.status and C.sh.factor can be used to scale elements
%
% RTS96 is only setup to use constant power loads (P).
% Constant current loads (I) and constant impedance loads (Z) are not
% currently being used. To simplify this script, only (P) loads are used
% in the calculation.
%
%


%% Store current operating point

n_sh = length(ps.shunt(:,1));

% save ps and save_state
load_initial = current_state(ps, C);

results = zeros((4*n_sh)+1,4);      % n_sh is a global variable
results(:,4) = 1;

results(1:n_sh,1) = load_initial.b;

for k = 1:length(load_initial.b)
    col=[1,2];
    results(4*k-3,col) = [load_initial.b(k), 1];
    results(4*k-2,col) = [load_initial.b(k), 0.75];
    results(4*k-1,col) = [load_initial.b(k), 0.5];
    results(4*k-0,col) = [load_initial.b(k), 0.25];
end

results(end,1) = -99;                   % -99 indicates a do nothing case


%% Network actions:
% Shunt table contains all the loads, all are non-zero as required by
% cosmic, thus entire table will be used.

LS_actions = ps.shunt;


%% Loop over all LS actions
beta = 1;
total_reward = [];  % Preallocate?

% Check all buses with loads
for bus = 1:length(results(:,1))     % Generate list of buses
    fprintf('Checking bus: %2.0d with shed percent %d\n',...
        results(bus,1),100*results(bus,2));
    
    % Reload case
    [ps, x, y] = load_sim_state(save_file);
    
    % Reset counters and variables
    iteration = 0;
    sim_time = 0;
    
    % get shunt line number
    index = find(results(bus) == ps.shunt(:,1));
    
    shed_percent = results(bus,2);
    
    % debugging
    % fprintf('Index: %d\n',index)
    
    if bus ~= -99   % bus has loads
        ps.shunt(index,C.sh.factor) = (1-shed_percent);
    end
    
    time_multiplier = 1;
    
    while sim_time <= t_max
        sim_time = sim_time + time_step;
        [outputs,ps,x,y] = rollout_continuation(ps, x, y, opt, C, time_step);
        
        if outputs.success == false
            results(bus,4) = 0;
            break;
        end
        
        load_current = current_state(ps, C);
        
        results(bus,3) = results(bus,3) + ...
            beta^iteration*reward_calculation(load_initial, load_current);
        iteration = iteration + 1;
        
        if (100*sim_time/115) >= time_multiplier*10
            fprintf('Sim percentage: %2.0f%%\n', 10*time_multiplier)
            time_multiplier = time_multiplier + 1;
        end
    end
        
end


end

