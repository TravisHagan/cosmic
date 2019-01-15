% Generate the result matrix
fields = {'LS50','LS75','LS0'};
ls = [50, 75, 0];

for k = 1:(numel(f)-1)
    results.(f{k}).bus = load_initial.b;
    results.(f{k}).reward = zeros(numel(load_initial.b));
    results.(f{k}).status = ones(numel(load_initial.b));
    results.(f{k}).Load_shedding_percent = ls(k);
end

% Do nothing case

results.LS0.bus = -99;
results.LS0.reward = 0;
results.LS0.status = 1;
results.LS0.Load_shedding_percent = 0;
results.case = Rollout_file;

for m = 1:numel(fields)
    shed_percent = results.(fields{m}).Load_shedding_percent;
    
    for n = 1:numel(results.(fields{m}).bus)
        cur_bus = results.(fields{m}).bus(n);
        fprintf('Bus %d, Shed percent %d\n',cur_bus, shed_percent)
    end
end