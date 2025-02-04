function test_global(varargin)
% TEST_GLOBAL - This script loads the channel measured in the experiments
% in a set of 12 antenna transmitters and 3 different receivers. Then, it
% executes the overall NetBeam framework, consisting of antenna
% orientation, antenna selection and SDP-based beamforming. The results
% show the overall transmit power required by different policies as well as
% the resulting gap between the offered and requested SNR.
%
% This script generates Fig. 12 of the publication :
% [1] C. Bocanegra, K. Alemdar, S. Garcia, C. Singhal and K. R. Chowdhury,
%     “NetBeam: Network of Distributed Full-dimension
%     Beamforming SDRs for Multi-user Heterogeneous Traffic,” IEEE Dynamic
%     Spectrum (DySpan), Newark, NJ, 2019
%
% Syntax:  test_global(environment)
%
% Inputs:
%    environment [optional] - String that takes the values 'indoor' and
%    'outdoor'. It selects the environment in which the experiments were
%    carried out. It defaults to indoor.
%
% Outputs: []
%
%
%------------- BEGIN CODE --------------



%% Configure workspace
if (nargin==1)
    environment = varargin{1};
elseif (nargin==0)
    clear all; clear classes;  %#ok
    close all; clc;
    environment = 'indoor';  % take indoor for example
else
    error('ERROR: The script only accepts 1 or none inputs\n');
end

fprintf(['--------\n'...
         'IMPORTANT - Make sure you have previously parsed the channels.\n' ...
         '>> CBG_parse_channels(indoor);\n' ...
         '>> CBG_parse_channels(outdoor);\n'...
         '--------\n\n']);
fprintf('Selected environment: %s\n\n',environment);

addpath('../BrewerMap/');  % Include additional colors: 'BrBG'|'PRGn'|'PiYG'|'PuOr'|'RdBu'|'RdGy'|'RdYlBu'|'RdYlGn'|'Spectral'
addpath('export_fig/');  % export figure in eps
addpath('data/');  % where results are stored (to be loaded)
set(0,'DefaultFigureColor','remove');  % No gray background in figures

%% SIMULATION CONFIGURATION
N                    = 12;  % Number of transmitter antennas (Fixed, this 
                            % is the antenna set used throughout
                            % experiments with real radios - SDRs, do not 
                            % modify)
M                    = 3;   % Number of receiver antennas (SDP is configured
                            % for 3 users. For a different number, please
                            % modify CBG_sdp_solver)
SNRdemands           = [0.7; 0.6; 0.6];  % Minimum SINR for each user, feel
                                         % free to distribute SNR across
                                         % the 3 (M) users, between 0 and 1
sigma2               = ones(12,1);  % Noise variance
Pt_max               = 1;  % Maximum normalized transmitted power per radio 

%% PARSE Data if not done before
if ~exist('RESULTS','var')
    load('RESULTS','indoor','outdoor','paramList');
elseif ~exist('outdoor','var') || ~exist('indoor','var')
    CBG_parse_experiments;  % parse experimental DATA
end

%% Configure data
policy_1stList = {'DIRECT-minVar_2-8','UM_8-8','PI_8-8','DIRECT-minVar_8-8','DIRECT-rand_8-8','random_8-8'};
legends        = {'DIRECT-UM','UM','PI','DIRECT','DIRECT-RD','Random'};
policy_2ndList = {'optimum','greedy','random'};

%% Execute
txPowerTot = [];
rxSNRsum = [];
for idxPolicy2 = 1:length(policy_2ndList)
    txPowerTot1 = [];
    rxSNRsum1 = [];
    for idxPolicy1 = 1:length(policy_1stList)
        policy_1st = policy_1stList{idxPolicy1};
        policy_2nd = policy_2ndList{idxPolicy2};

        %% 1 stage: Antenna orientation (pre-stored channel)
        % To get the new channels, please run "CBG_parse_channels.m"
        ws = load(sprintf('CHANNEL_%s_%s',environment,policy_1st),'H');
        H = ws.H;

        %% 2 stage: Antenna selection
        [finalAssign,~,assignation] = CBG_antSel(H,SNRdemands,policy_2nd);

        %% 3 stage: Beamforming
        repeat = true;
        SNRdemands1 = SNRdemands;
        while repeat
            [w, SNR, repeat] = CBG_sdp_solver(H, N, M, Pt_max, SNRdemands1, sigma2, assignation);
            if repeat
                % Adjust demanded SNR and try it again
                [maxSNR,i] = max(SNRdemands1);
                minSNR = min(SNRdemands1);
                delta = 0.05;
                SNRdemands1(i) = SNRdemands1(i) - delta;
            end
        end
        
        %% Final: show results
        fprintf('Policy 1: %s, Policy 2: %s -> SNR: | ',policy_1st,policy_2nd);
        fprintf('%.7f |',SNR);
        fprintf('\n');
        fprintf('Power used: %.5f\n',sum(sum(abs(w).^2)));
        
        %% Append results - Tx power
        txPowerTot1 = [txPowerTot1 sum(sum(abs(w).^2))];  %#ok<AGROW>
        
        [~,lostID] = find(SNR - SNRdemands.' > 1e-4);
        if isempty(lostID); lostSNR = 0;
        else;               lostSNR = SNRdemands(lostID).' - SNR(lostID);
        end
        rxSNRsum1 = [rxSNRsum1 sum(lostSNR)];  %#ok<AGROW>
    end
    txPowerTot = [txPowerTot ; txPowerTot1];  %#ok<AGROW>
    rxSNRsum = [rxSNRsum ; rxSNRsum1];  %#ok<AGROW>
end

%% PLOT OVERALL TRANSMIT POWER
groupLabels = policy_2ndList;
stackData = txPowerTot;
plotBarStackGroups(stackData, groupLabels,1);
lg = legend(legends);
set(lg,'FontSize',8);
title(sprintf('%s',environment),'FontSize',12);
ylabel('Overall tx. power (linear)','FontSize',12);
% Modify colors
a = findobj(gca,'type','bar');
a(6).FaceColor = [0 104 255]./255;
a(1).FaceColor = [76 76 76]./255;
a(2).FaceColor = [127 127 127]./255;
a(3).FaceColor = [178 178 178]./255;
a(4).FaceColor = [204 204 204]./255;
a(5).FaceColor = [229 229 229]./255;
xlim([0.5 3.5]);
pos = get(gcf, 'Position');
set(gcf,'position',[pos(1),pos(2),677,235]);
grid on;

groupLabels = policy_2ndList;
stackData = rxSNRsum;
plotBarStackGroups(stackData, groupLabels,2);
lg = legend(legends);
set(lg,'FontSize',8);
title(sprintf('%s',environment),'FontSize',12);
ylabel('Overall SNR lost (linear)','FontSize',12);
% Modify colors
a = findobj(gca,'type','bar');
a(6).FaceColor = [0 104 255]./255;
a(1).FaceColor = [76 76 76]./255;
a(2).FaceColor = [127 127 127]./255;
a(3).FaceColor = [178 178 178]./255;
a(4).FaceColor = [204 204 204]./255;
a(5).FaceColor = [229 229 229]./255;
xlim([0.5 3.5]);
pos = get(gcf, 'Position');
set(gcf,'position',[pos(1),pos(2),677,235]);
grid on;