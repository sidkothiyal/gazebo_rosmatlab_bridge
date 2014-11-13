function f = arm_shooting()
% Example of trajectory optimization for a 
% double pendulum model using shooting and least-squares Gauss Newton method
%
% Gowtham Garimella ggarime1(at)jhu.edu
% Marin Kobilarov marin(at)jhu.edu

% time horizon and segments
tf = 1;
S.N = 4;
S.h = tf/S.N;
S.m = 2;
S.n = 4;

% cost function parameters
S.Q = .0*diag([5, 5, 1, 1]);
S.R = .01*diag([1, 0.1]);
S.Qf = diag([100, 100, 20, 20]);

S.Qs = sqrt(S.Q);
S.Rs = sqrt(S.R);
S.Qfs = sqrt(S.Qf);

S.f = @arm_f;

S.sim = Gazebo_MatlabSimulator;%Creates a Matlab Bridge using a helper class
S.sim.Configure(0.001,100);%Configure the physics engine to have a time step of 1 milli second and real time rate is 100
S.steps = uint32(round((0:S.h:tf)/S.sim.physxtimestep));%Converts the time into physics time steps
% For example if the open loop trajectory is 1 second with 4 segments then the time is [0, 0.25, 0.5, 0.75, 1] and the steps are [0 250 500 750 1000] 
% since physics time step is 1 millisecond

% initial state
x0 = [-1; 0; 0; 0;];%State is Joint angles(1,2) and Joint Velocities(1,2)
S.xf = [1; 0; 0; 0];%Final state

S.x0 = x0;

% initial control sequence
us = 0*ones(2,S.N);%Initial Guess of controls. For N segments there are N controls

% us = [0.9008   10.4779   13.3308    2.9975;
%     9.3994    0.0811   -6.0542    5.9867];
%us =[25*ones(1,S.N); 5*ones(1,S.N)]; %Other examples of initialization of us

xs = zeros(4,S.N+1); 

%%% Setup the Visualization of the states and controls [May Not be obvious how to set this up but very useful for debugging]
figure(1),clf,
S.phandle(1) = plot(0,0);
hold on, S.phandle(2) = plot(0,0,'r');
set(S.phandle(1),'XData',S.steps);
set(S.phandle(1),'YDataSource','xs(1,:)');
set(S.phandle(2),'XData',S.steps);
set(S.phandle(2),'YDataSource','xs(2,:)');
figure(2),clf,
S.phandle(3) = plot(0,0);
hold on, S.phandle(4) = plot(0,0,'r');
set(S.phandle(3),'XData',(S.steps(1:end-1)));
set(S.phandle(3),'YDataSource','us(1,:)');
set(S.phandle(4),'XData',(S.steps(1:end-1)));
set(S.phandle(4),'YDataSource','us(2,:)');
hold on

m = size(us,1);
N = S.N;
lb=repmat([-50; -50], N, 1); % can incorporate upper and lower bound
ub=repmat([50; 50], N, 1);
%%%Setup the Optimization Problem
options = optimset('FinDiffRelStep',0.001, 'TolX',1e-2,'TolFun',1e-4);
us = lsqnonlin(@(us)arm_cost(us, S), us, lb, ub,options);
% Display final control and state information
disp('us');
disp(us);
% % update trajectory
xs = sys_traj(x0, us, S);
% 
disp('xs');
disp(xs);


function y = arm_cost(us, S)
% this the arm costs in least-squares form,
% i.e. the residuals at each time-step

us = reshape(us, S.m, S.N);

xs = sys_traj(S.x0, us, S);

N=size(us,2);

%y = zeros(S.N*(S.n+S.m), 1);
y=[];
for k=1:N
  y = [y; S.Rs*us(:,k)];
end

for k=2:N
  y = [y; S.Qs*xs(:,k)];
end
y = [y; S.Qfs*(xs(:,N+1)-S.xf)];
disp('Cost: ');
disp(0.5*y'*y);
 
function xs = sys_traj(x0, us, S)

N = size(us, 2);
jointids = [1 2];
%xs(:,1) = x0;
mex_mmap('reset',S.sim.Mex_data);
pause(0.01);

mex_mmap('setmodelstate',S.sim.Mex_data,'double_pendulum_with_base',[],...
    uint32(jointids)-1,[x0(1:2);x0(3:4)]); %Set the initial Joint angles

[~, JointData] = mex_mmap('runsimulation',S.sim.Mex_data, uint32(jointids)-1, us, ...
                                                    [], [], S.steps);% Run the simulation and collect the joint angles and velocities along the trajectory
xs([1,3],1:(N+1)) = JointData(:,1:2:(2*(N+1)));
xs([2,4],1:(N+1)) = JointData(:,2:2:(2*(N+1)));
%Map the angles to -pi to pi
A = rem(xs(1:2,:),2*pi);
A(A>pi) = A(A>pi)-2*pi;
A(A<-pi) = A(A<-pi)+2*pi;
xs(1:2,:)= A;
% Check if initial state matches with S.x0
if norm(xs(:,1) - S.x0(:,1))>1e-3
    disp('xs is not starting from x0');
end

refreshdata(S.phandle,'caller');
pause(0.01);

