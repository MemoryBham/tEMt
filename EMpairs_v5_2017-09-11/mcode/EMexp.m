function EMexp(params)
%% default params
if nargin ==0
    %     params.basepath = 'C:\Experiments\EMpairs_v4_2016-1007';
    %     params.start_idx = [];% can be used to start from a specific BLOCK on
    %     params.initial_diff_level = 14;
    %     params.p2f = ['C:\Experiments\EMpairs_v4_2016-1007\image_data\EMtune\fVSp_resized\empairs',filesep];
    %     params.concept_neurons = {'f_','p_'};
    %     %params.p2f = [params.basepath,filesep,'image_data',filesep,'screening_2016-0523',filesep,'empairs',filesep];
    %     %params.concept_neurons = {'f_','p_'};
    %     %params.data_ID = ['P02_fVSp_SE02'];
    %     %params.debugmode = 'no';
    %     params.data_ID = ['debug'];
    %     params.debugmode = 'mode2';
    %     params.p2log = [params.basepath,filesep,'log',filesep,'EM',filesep];
    %     params.Ed = [2 1];
    %     params.Ret =  2;
    %     params.sc_trsh = [.01 .01];% change treshold [hits misses]
    %     params.r = [3 3];% change rate [hits misses]
    %     params.savep = [params.basepath,filesep,'params',filesep];
    %     params.baseperf = .6;
    %     params.enctrig = 7;%will be 51,52,53
    %     params.rettrig = 7;%will be 61,62,63
    %     params.starttrig = 255;
    %     get_clock_time;
    %     params.fid = fopen([params.p2log,params.data_ID,'_',date,'_',ct,'_LogFile_EMtask.txt'],'w');
end
%% DOC
% 21/06/2016 - FRO: fixed bug in the readout of the random numbers in distractor task
%            - FRO: add nanmedian to adaptive measurement of performance to
%            avoid NaN-related error
%27/06/2026 - FRO: fixed bug in random number readout for distractor task
%28/06/2016 - FRO: fixed NaN values in response output
%04/07/2016 - FRO: fixed bug in response output
%05/07/2016 - FRO: fixed bug in response output
%06/07/2016 - FRO: fixed bug in how foils get selected
%06/07/2016 - FRO: fixed bug in distractor number sequence
%27/04/2017 - FRO: code revision, fixed minor bugs
%28/04/2017 - FRO: code revision, fixed minor bugs
%29/04/2017 - FRO: code revision, fixed minor bugs
%30/04/2017 - FRO: code revision, fixed minor bugs
%01/05/2017 - FRO: code revision, fixed minor bugs
%02/05/2017 - FRO: code revision, added some changes to the concept-neuron pair assignments, fixed minor bugs
%03/05/2017 - FRO: code revision, changed the priority settings during
%encoding and retrieval
%03/06/2017 - FRO: added flags if crash happens during task to start again
%from either encoding or retrieval
%also changed the way hit rate is computed as there was
%a bug in how the hit rate was calculated because of
% a change introduced previously

%% START
try
    %% add folder with m-files to MATLAB path
    addpath([params.basepath,filesep,'mcode',filesep]);
    
    %% Clear the workspace and the screen
    sca;
    close all;
    
    %% setting up Psychtoolbox
    PsychDefaultSetup(2);
    AssertOpenGL;
    LoadPsychHID;
    HideCursor;
    
    %% prep trigger box
    if strcmp(params.trg, 'serial')
        params.trg_handle = IOPort('OpenSerialPort', 'COM5'); % try out COM3 otherwise, creates trigger handle
        params.trg_data = uint8(1); % value that is being sent
    elseif strcmp(params.trg, 'ttl')
        params.daqID  = DaqDeviceIndex;
        if isempty(params.daqID)
            error('trigger box not connected');
        else
            err = DaqDConfigPort(params.daqID,[],0);
            out_ = DaqDOut(params.daqID,0,0); % reset
        end
    elseif strcmp(params.trg, 'utrecht')
        %Trigger output is at 115200
        params.serial = serial('COM4','BaudRate',115200);
        fopen(params.serial)
    elseif strcmp(params.trg, 'debug')
    end
    
    %% setting up the trial structure and response buttons
    [params] = set_up_stimuli(params,'n');   
    
    %% implement non-preferred stimuli
    [params.btns] = SetExpButtons;
    
    %% get screen params
    [params] = get_screen_params(params);
    
    %% Set up alpha-blending for smooth (anti-aliased) lines
    Screen('BlendFunction', params.window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    
    %% Retreive the maximum priority number
    params.topPriorityLevel = MaxPriority(params.window);
    
    %% load in break image from file
    [params] = read_bckgrnd_image(params,'n');
    
    %% load in all images fro m file
    [params] = read_stim_images(params);
    
    %% compute corrdinates
    [params] = calculate_coordinates(params);
    params.Yoffs = 0;% controls center of screen offset
    
    % screen coordinates y-axis
    params.Y(1) = params.Yoffs + params.baseRect(end);
    params.Y(2) = params.yCenter+200;
    params.Y(3) = params.yCenter+200;
    
    % screen coordinates x-axis
    params.X(1) = params.xCenter;
    params.X(2) = params.xCenter-500;
    params.X(3) = params.xCenter+300;
    
    %% set initial difficulty level
    if isempty(params.start_idx) % For new sessions. This will be skipped when restarting a crashed session.
        params.start_idx=1;
        params.trl_idx = params.start_idx:(params.start_idx-1)+(params.diff_level);
    end
    
    %% intialize performance loging
    if ~isfield(params, 'c')
        params.c =  0; %params.start_idx-1;
        params.perf = cell(size(params.stim_mat.seq,2),1);
    else
    end
    
    %% prepare LOGFILE
    [params] = prepare_EMlogfile(params);
    
    %% create randum numbers for the distractor trial
    rand('state',sum(100*clock));
    params.rnum = randi(99,1000,1);
    params.dist_trl_idx = 0;
    
    %% loop over trials
    %     f1 = 0;
    endExp = 0;
    params.st = GetSecs; % get start time
    
    %% save Exp-parameter file
    get_clock_time;
    save ([params.savep, params.data_ID, '_', date, '_', ct, '_params_initialized.mat'],'params');
    
    %% send the start trigger
    if ~strcmp(params.trg, 'debug')
        send_start_trigger(params);
        send_start_trigger(params);
        send_start_trigger(params);
    end
    
    %% compute the number of frames
    [params.Enc] = compute_numFrames(params,params.Ed);
    [params.Ret] = compute_numFrames(params,params.RetTime);
    [params.Ins] = compute_numFrames(params,2.5);
    [params.Dis] = compute_numFrames(params,.125);
    [params.Iti] = compute_numFrames(params,1);
    [params.Bre] = compute_numFrames(params,5/100);
    [params.End] = compute_numFrames(params,5);
    
    %% testing crash resistance
    disp('params.stim_mat.seq: ');
    disp(params.stim_mat.seq);
    disp('params.trl_idx: ');
    disp(params.trl_idx);
    %% start the graphics
    while endExp<1
        %% flag reset until l.212
        % the way flags are used is as follows: in the beginning
        % flag1(encoding( and flag2(retrieval) are reset to 1. Then we run
        % encoding and switch flag1 to "0". Then we run retrieval and
        % switch flag2 to "0". Then we repeat the while loop and switch
        % flag1 and flag2 back to "1".
        if isfield(params,'flag1') && isfield(params,'flag2')
            if ( params.flag1 ~=1 ) && ( params.flag2 ~=1 ) % encoding and retrieval block both done! reset flags
                
                params.flag1 = 1;
                params.flag2 = 1;
                
                %% count blocks
                params.c = params.c+1;
                
                %% flag  trl index
                if params.trl_idx(end) >= length(params.stim_mat.seq)
                    params.trl_idx(params.trl_idx>length(params.stim_mat.seq)) = [];
                    endExp = 1;
                end
                
            end
        else % if flag1 and flag2 do not exist yet, create them here.
            params.flag1 = 1;
            params.flag2 = 1;
            
            %% count blocks
            params.c = params.c+1;
            
            %% make sure we dont have more trials than stimuli
            if params.trl_idx(end) >= length(params.stim_mat.seq)
                params.trl_idx(params.trl_idx>length(params.stim_mat.seq)) = [];
                endExp = 1;
            end
            
        end
        
        %%
        if params.flag1 == 1
            %% Instructions Encoding
            if params.c == 1
                instructions1(params);
            end
            write_output2log(params,['ENC',num2str(params.c)]);
            
            %% Encoding task
            [params] = run_encoding(params);
                        
            %% Instruction distractor task
            % odd/even number judgement
            if params.c ==1
                instructions2(params);
            end
            
            %% Distractor task
            [~ ,~] = distracter_task(params, 15);
            
        end
        
        %%
        if params.flag2 ==1
            %% Instruction Retrieval task
            if params.c ==1
                instructions3(params);
            end
            write_output2log(params,['RET',num2str(params.c)]);
            
            %% Retrieval task
            [params] = run_retrieval(params);
            Priority(0);
            
            disp('params.stim_mat.seq: ');
            disp(params.stim_mat.seq);
            disp('params.trl_idx: ');
            disp(params.trl_idx);
        end
        
        %% adaptive task-difficulty
        a = zeros(1,length(params.trl_idx));
        for kt = 1:length(params.trl_idx)
            a(kt) = params.perf{params.trl_idx(kt)}.H; % 1 and 0?
        end
        
        a = nansum(a)/length(a);
        
        a = (a-1/4)/(1-(1/4));% hit rate corrected for guesses
        if isnan(a)
            error('NaN value in hit rate detected');
        end
        
        if (a >= .95)
            params.diff_level = params.diff_level+5;
        elseif (a >= .75) && (a <.95)
            params.diff_level = params.diff_level+3;
        elseif (a > .65) && (a <.75)
            params.diff_level = params.diff_level+1;
        elseif (a >= .55) && (a <=.65)
            params.diff_level = params.diff_level;
        elseif (a < .55) && (a > .35)
            params.diff_level = params.diff_level-1;
        elseif (a <= .35) && (a > .15)
            params.diff_level = params.diff_level-3;
        elseif a <= .15
            params.diff_level = params.diff_level-5;
        end
        
        if params.diff_level <=4; params.diff_level =4;end
        %if params.diff_level >=24; params.diff_level =24;end;
        
        % update difficulty
        params.trl_idx = max(params.trl_idx)+1 : max(params.trl_idx)+(params.diff_level); %increments by difficulty. In tEMt I have to use max(). In the previous version (end) was used. However, here we keep the scrambled trial index of retrieval for crash resistance in the params file. Previously that retrieval trial index did not leave the function.
        
        %% measure time of exp
        st = GetSecs;
        d = (st-params.st)/60;
        if d > params.expDur
            endExp = 1;
        end
        
        %% break trial
        if endExp ~=1
            write_output2log(params,['BreakBeg',num2str(params.c),'\t',num2str(GetSecs)]);
            wait_barEM(params);
            write_output2log(params,['BreakEnd',num2str(params.c),'\t',num2str(GetSecs)]);
        end
        
    end
    
    %%  save the set of final parameters
    get_clock_time;
    save([params.savep, params.data_ID, '_', date, '_', ct, '_params_completed.mat'],'params');
    
    %% END
    end_of_task(params);
    
    %% Clear the screen and the memory
    sca;
    close all;
    fclose(params.fid);
    return;
    
catch er
    
    %% save the set of final parameters
    get_clock_time;
    save([params.savep,params.data_ID,'_',date,'_',ct,'_params_aborted2.mat'],'params');
    send_crashTrig(params)
    sca;% Clear the screen
    close all;
    fclose(params.fid);
    psychrethrow(psychlasterror)
    error('program aborted');
    er.message
    
end
end