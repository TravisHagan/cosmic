function output = reward_calculation(load_initial, load_current)
% reward_calculation Summary of this function goes here
%   Detailed explanation goes here

reward = 0;
count = 0;

for k=1:length(load_initial.b)
    [reward, count] = get_load_reward(load_initial, load_current, reward, count, k);
end

output = reward/count;
end

