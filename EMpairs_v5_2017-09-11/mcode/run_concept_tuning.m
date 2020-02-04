function [ot,resp] = run_concept_tuning(params,trl_idx)
% made tuning self-paced on 06/07/2016
% changed tuning from self-paced to timeout on 06/07/2016
%27/04/2017 - FRO: changed initla vbl sample to correct sync issues

%% draw image on screen
send_ttl(params,7);
ot = cell(length(trl_idx),3);
tStart = GetSecs;
[ot(1,1)] = {num2str(tStart)};        
[ot(1,2)] = {num2str(GetSecs)};
 
% Perform initial Flip and sync us to the retrace:
vbl = Screen('Flip', params.window);

%%
f=0;
response = [];
rt = [];
for frame = 1:params.numFrames(1)
    
    Screen('FillRect',params.window, params.bc_color);
    Screen('DrawTexture', params.window, params.imageTexture,[],  params.centeredRect, 0);
    
    % display response category information below stimulus image
    %DrawFormattedText( params.window, params.resp_cat1 ,X(2), Y(2)+100, [0 0 0]);
    %DrawFormattedText( params.window, params.resp_cat2 ,X(3), Y(3)+100, [0 0 0]);
    
    %Tell PTB no more drawing commands will be issued until the next flip
    Screen('DrawingFinished', params.window);
    
    %Flip to the screen
    vbl = Screen('Flip', params.window, vbl + (params.waitframes - 0.5)*params.ifi);
        
    %% this section is to poll responses  
    if f<1
        if strcmp(params.debugmode,'no') || strcmp(params.debugmode,'mode2')
            [response,rt] = get_response_tuning(tStart,params.btns);
            if ~isempty(response);f=1;end;            
        end;
    end;
    
end;
send_ttl(params,0);       

[ot(1,3)] = {num2str(GetSecs)};
%Screen('Close',params.imageTexture{trl_idx});

%%
if isempty(response)
    response = NaN;
end;
if isempty(rt)
    rt = NaN;
end;

%%
resp.btn = response;
resp.rt = rt;%+ params.stimd;
%%
out = [num2str(trl_idx),'\t',params.Imf(trl_idx).name,'\t',params.ID{trl_idx}(1),'\t',num2str(resp.btn),'\t',ot{1},'\t',ot{2},'\t',ot{3},'\t',num2str(resp.rt),'\n'];
write_output2log_concept_tuning(params.fid,out);

%%
% 26/04/2017
%     %% this section is to poll responses, maintained for backup
%     
%     if strcmp(params.debugmode,'no') || strcmp(params.debugmode,'mode2')
%         f=0;
%         %while f<1            
%             [response,rt] = get_response_tuning(tStart,params.btns);
%             %KbReleaseWait;
%             %GpWait(params.btns);
%             if ~isempty(response)                
%                 f=1;
%                 break;
%             end;
%         %end;
%     end;
