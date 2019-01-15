function yhat = Data_correction_module(y, Ybus)

% Load testcase
testcase = 'RTS_96_MatPower';
mpc = loadcase(testcase);
buss = mpc.bus(:,1);
system = ext2int(mpc);

buss = ps.bus(1,:);




system.Nbus = size(system.bus,1); % number of buses
system.Nbranch = size(system.branch,1); % number of branches
[H] = ComplexPhasor(system,Ybus); % Linear operator

% Deployed PMUs
binocoffcient = 7;
pmu_meter = find(sum(buss == [121,116,123,103,110,107,102,221,216,223,203,210,207,202,321,316,323,303,310,307,302],2)); % RTS 96 bus system
binormial_label =[(randperm(7,binocoffcient)), (randperm(7,binocoffcient)) + 7, (randperm(7,binocoffcient)) + 14];
pmu_meter = sort(pmu_meter(binormial_label));

% Flow meters
pmu_measured_rowmeter = [];
Voltage_range = [];
Iflow_range = [];
numberofatoms = [];

for ik = 1 : 1 : length(pmu_meter)
    [temp, extra] = genmeter(pmu_meter(ik),system,2);
    pmu_measured_rowmeter = [pmu_measured_rowmeter ;temp];
    Voltage_range = [Voltage_range ; find(pmu_measured_rowmeter == temp(1))];
    for r = 2 : 1: length(temp)
        Iflow_range = [Iflow_range ; find(pmu_measured_rowmeter == temp(r))];
    end
    numberofatoms = [numberofatoms ; length(temp)];
end

% Compute partial linear operator to decrease computation time
HH = H(pmu_measured_rowmeter,:);
[UU,SS,VV] = svd(HH);
UU = UU(:,1:rank(HH));
Hinv = UU*UU';
OrthoH = (eye(size(HH,1))-Hinv);

% BOMP
threshold = 0.0635;%0.0529;%0.0635;
beta = zeros(length(pmu_meter),1);
diagbeta = zeros(size(HH,1),1);
supportbeta = [];
supportdiagbeta = [];
select = [];

for ii = 1 : 1: length(pmu_meter)
    seti = find(ismember(pmu_measured_rowmeter,genmeter(pmu_meter(ii),system,2)));
    for j = 1 : 1 : length(pmu_meter)
        setj = find(ismember(pmu_measured_rowmeter,genmeter(pmu_meter(j),system,2)));
        w(ii,j) = y(seti,1)'*OrthoH(:,seti)'*OrthoH(:,setj)*y(setj,1);
    end
end

residue = (eye(length(y))-Hinv)*diag(exp(-1j*diagbeta))*y;
termination = 2;
kk = 0;
while(termination > threshold && kk <10 )
    for itr = 1 : 1: length(pmu_meter)
        settt = find(ismember(pmu_measured_rowmeter,genmeter(pmu_meter(itr),system,2)));
        projection(itr) = norm(residue(settt))^2/length(settt);
        if(ismember(itr,select))
            projection(itr) = 0;
        end
    end
    
    [val, idx] = sort(projection,'descend');
    select = idx(1);
    supportbeta = [supportbeta ,select];
    supportdiagbeta = [supportdiagbeta; find(ismember(pmu_measured_rowmeter,genmeter(pmu_meter(select),system,2)))];
    [beta,diagbeta] = gradient_descent(beta,supportbeta,supportdiagbeta,y,length(pmu_meter),pmu_measured_rowmeter, pmu_meter,system,OrthoH,Hinv,diagbeta,w);
    
    residue = (eye(length(y))-Hinv)*diag(exp(-1j*diagbeta))*y;
    termination = norm(residue)^2;
    kk = kk + 1;
end
% supportbeta

phialpha = diag(exp(1j*diagbeta));
yhat = pinv(phialpha)*y;
end


function [out, outt] = genmeter(list,system,status)

Nbus = size(system.bus,1);
Nbranch = size(system.branch,1);

poslist = find(ismember(system.branch(:,1),list'));
neglist = find(ismember(system.branch(:,2),list'));
list = find(ismember(system.bus(:,1),list'));
if(status == 1)
    out = [list];
    outt = [list];
else
    out = [list; poslist + Nbus; neglist + Nbus + Nbranch;];
    outt = [list; system.branch(poslist,1); system.branch(neglist,2)];
end
end

function [out, diagout] = gradient_descent(beta, support,supportdiagbeta,y,N,pmu_measured_rowmeter, pmu_meter,system,OrthoH,Hinv,diagbeta,w)

backtrackingalpha = 0.1;
backtrackingbeta = 0.2;

maxitr = 1000;

threshold = 1e-7;
tempdiagbeta = diagbeta;
itr = 0;
diaggradient = zeros(length(diagbeta),1);
residue =  norm((eye(length(y))-Hinv)*diag(exp(-1j*diagbeta))*y)^2 ;
grad = 1;

while(grad > threshold && itr < maxitr)
    step_size = 1;
    for kk = 1 : 1: length(support)
        select = support(kk);
        sum1 = 0;
        sum2 = 0;
        for i = setdiff([1:N],select)
            sum1 = sum1 + 1j*exp(1j*(beta(select)-beta(i)))*w(select,i);
            sum2 = sum2 - 1j*exp(1j*(beta(i)-beta(select)))*w(i,select);
        end
        gradient(kk) = real(sum1 + sum2);
        diaggradient(find(ismember(pmu_measured_rowmeter,genmeter(pmu_meter(select),system,2)))) = gradient(kk);
    end
    
    tempdiagbeta(supportdiagbeta) = diagbeta(supportdiagbeta) - step_size*diaggradient(supportdiagbeta);
    newresidue =  norm((eye(length(y))-Hinv)*diag(exp(-1j*tempdiagbeta))*y)^2 ;
    
    while(newresidue > residue - step_size*backtrackingalpha*norm(gradient)^2)
        step_size = backtrackingbeta*step_size;
        tempdiagbeta(supportdiagbeta) = diagbeta(supportdiagbeta) - step_size*diaggradient(supportdiagbeta);
        newresidue = norm((eye(length(y))-Hinv)*diag(exp(-1j*tempdiagbeta))*y)^2;
    end
    
    beta(support) = beta(support) - step_size*(gradient)';
    diagbeta(supportdiagbeta) = diagbeta(supportdiagbeta) -  step_size*diaggradient(supportdiagbeta);
    
    residue =  norm((eye(length(y))-Hinv)*diag(exp(-1j*diagbeta))*y)^2 ;
    grad = mean(abs(real(gradient)));
    itr = itr + 1;
end

out = beta;
diagout = diagbeta;
end