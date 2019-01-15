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


function [reward, count] = get_load_reward(load_i, load_c, reward, count, k)
ratio = [0,0];
ratio(1) = load_c.active(k)/load_i.active(k);
ratio(2) = load_c.reactive(k)/load_i.reactive(k);

ratio(Inf == ratio) = 0;

reward = reward + ratio(1) + ratio(2);
count = count + 1;

end
