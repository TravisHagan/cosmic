function y = Spoofing_Attack(y, ps)
%Spoofing_Attack modifies simulation variables to implement a spoofing
%attack in Cosmic
%   
% Inputs:
% y - current simulation variables
% ps - power system
% t - current time
% attack - global variable
%
% Assume t is relative to start of sim
% y matrix
% Vmag = (1:2:n_bus) = (2*ix-1)
% Vang = (2:2:n_bus) = (2*ix)

global attack

%% Options
ramp_rate = 10;     % Max ramp of clock carry off (degrees/second)
max_attack = 45;    % Maximum angle change
attack_direction = 1;   % -1 - lag, 1 - lead


%% Generate list of attack bus index
ix = zeros(numel(attack.bus),1);
for k = 1:numel(attack.bus)
    ix(k) = find(attack.bus(k) == ps.bus(:,1));
end


%% Attack start values
if attack.flag
    attack.values = zeros(numel(attack.bus),1);
    for k = 1:numel(ix(k))
        attack.values_i(k) = y(2*ix(k));
    end
    attack.flag = false;
end


%% Generate new values
if attack.t_start <= attack.t_cur && attack.t_cur <= attack.t_end
    for k = 1:numel(ix)
        attack_angle = attack_direction*ramp_rate*(attack.t_cur-attack.t_start);
        
        if abs(attack_angle) > max_attack
            attack_angle = 90;
        end
        
        y(2*ix(k)) = attack_angle + attack.values_i(k);
        attack.values(k) = y(2*ix(k));
    end
end

end

