function results = RolloutPolicy(ps, opt, C, time, save_file, Rollout_file)
% RolloutPolicy is a load shedding algorithm that determines which load to
% shed
%   
% Based on Carter Lasseter's Python based system for PSSE
%
% Only configured for constant power loads (P).
%
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

global attack;

%% Store current operating point

% save ps and save_state
load_initial = current_state(ps, C);

%% Generate the result matrix
fields = {'LS50','LS75','LS0'};
ls = [50, 75, 0];

for k = 1:(numel(fields)-1)
    results.(fields{k}).bus = load_initial.b;
    results.(fields{k}).reward = zeros(numel(load_initial.b),1);
    results.(fields{k}).status = ones(numel(load_initial.b),1);
    results.(fields{k}).demand_lost = zeros(numel(load_initial.b),1);
    results.(fields{k}).Load_shedding_percent = ls(k);
end

% Do nothing case
results.LS0.bus = -99;
results.LS0.reward = 0;
results.LS0.status = 1;
results.LS0.Load_shedding_percent = 0;
results.LS0.demand_lost = 0;
results.case = Rollout_file;


%% Network actions:
% Shunt table contains all the loads, all are non-zero as required by
% cosmic, thus entire table will be used.

LS_actions = ps.shunt;


%% Loop over all LS actions
beta = 1;

% Check the results

for m = 1:numel(fields)
    shed_percent = results.(fields{m}).Load_shedding_percent;       % Current load shed percent
    
    for n = 1:numel(results.(fields{m}).bus)                        % List of all buses with loads
        cur_bus = results.(fields{m}).bus(n);                       % Current bus with load
        
        fprintf('Checking bus: %2.0d with shed percent %d.',...
            cur_bus,shed_percent);
    
        % Reload case
        [ps, x, y] = load_sim_state(save_file);
    
        % Reset counters and variables
        iteration = 0;
        time.sim = 0;
    
        % get shunt line number
        index = find(cur_bus == ps.shunt(:,1));
    
        % debugging
        % fprintf('Index: %d\n',index)
    
        if cur_bus ~= -99   % bus has loads
            ps.shunt(index,C.sh.factor) = (1-shed_percent/100);
        end
    
        time.multiplier = 1;
        t_step = time.step;         % Load default time step
        attack.t_cur = attack.t_start;
    
        while time.sim <= time.max
            % Variable time step
            if time.sim < 5
                t_step = time.step;
            elseif time.sim >= 5 && time.sim < 10   % (5 <= time < 10)
                t_step = time.step1;
            elseif time.sim >= 10               % (10 < time)
                t_step = time.step2;
            end
            time.sim = time.sim + t_step;
        
            [outputs,ps,x,y] = rollout_continuation(ps, x, y, opt, C, t_step);
            attack.t_cur = attack.t_cur + outputs.t_simulated(end);
        
            % Simulation failed or blackout
            if outputs.success == false
                results.(fields{m}).status(n) = 0;
                break;
            end
            
            % Store total demand lost
            results.(fields{m}).demand_lost(n) =...
                results.(fields{m}).demand_lost(n) + outputs.demand_lost;
            
            load_current = current_state(ps, C);
       
            results.(fields{m}).reward(n) = results.(fields{m}).reward(n)+...
                beta^iteration*reward_calculation(load_initial, load_current);
            
            iteration = iteration + 1;
            
            %{
            % Additional Outputs
            if (100*time.sim/time.max) >= time.multiplier*25
                fprintf('Sim percentage: %2.0f%%\n', 25*time.multiplier)
                time.multiplier = time.multiplier + 1;
            end
            %}
        end
        
        keyboard
        
        fprintf(' Reward: %2.2f. Demand_lost %2.3f\n',results.(fields{m}).reward(n),results.(fields{m}).demand_lost(n));
    end
end

outfile = strcat('Results\',Rollout_file,'.mat');
save(outfile, 'results');

end

