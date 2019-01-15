%% Test the spoofing attack algorithm

clc;
clear;

if ~(ismcc || isdeployed)
    addpath('../data');
    addpath('../numerics');
end

%%

C = psconstants;
opt = psoptions;

load('save_state.mat');

global attack;
attack.bus              = 101;
attack.t_start          = 5;
attack.t_end            = 10;
attack.t_cur            = 0;
attack.flag             = true;
attack.values_i         = [];
attack.values           = [];

temp = 0:0.01:10;
y_mat = zeros(numel(y),numel(temp));

count = 1;
for t = temp
    if ~isempty(attack)
        if attack.t_start <= t && t <= attack.t_end
            if opt.sim.attack_data
                y = Spoofing_Attack(y, ps);
            end
        end
    end
    y_mat(:,count) = y;
    count = count+1;
end
