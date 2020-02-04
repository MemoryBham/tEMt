function foil_idx = get_foil_indices_tEMt(params, trl_idx)

% trl_idx = [5     4    10     2     6     9     1     8     7     3];
allIm = params.stim_mat.seq(:,params.trl_idx);
foil_idx = zeros(3,size(params.trl_idx,2));
for lk = params.trl_idx
    tgt = params.stim_mat.seq(:,lk);
    distIdx = ~ismember(allIm, tgt);
    dist_img = allIm(distIdx);
    
    dist_img = dist_img(randperm(size(dist_img,1)));
    % sanity check
    if any(ismember(tgt,dist_img(1:3)))
        error('One of the target stimuli overlaps with the distractors!')
    else
        foil_idx(:,lk) = dist_img(1:3);
    end
end
end % end of function



