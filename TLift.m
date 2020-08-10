function out_score = TLift(in_score, gal_cam_id, gal_time, prob_cam_id, prob_time, ...
num_cams, tau, sigma, K, alpha)
%% Function for the Temporal Lifting (TLift) method
%  TLift is a model-free temporal cooccurrence based score weighting method proposed in "Interpretable and Generalizable Person Re-Identification with Query-Adaptive
%      Convolution and Temporal Lifting".
%  Inputs:
%      in_score: the similarity score of size [num_gals, num_probs] between the gallery and probe sets.
%      gal_cam_id: camera index for samples in the gallery set.
%      gal_time: time stamps of samples in the gallery set.
%      prob_cam_id: camera index for samples in the probe set.
%      prob_time: time stamps of samples in the probe set.
%      num_cams: the number of cameras.
%      tau: the interval threshold to define nearby persons.
%      sigma: the sensitivity parameter of the time difference.
%      K: parameter of the top K retrievals used to define the pivot set P.
%      alpha: regularizer for the multiplication fusion.
%      All the cam_id and time inputs are column vectors, and they are in the same order corresponding to 
%      rows (gallery) or columns (probe) of the in_score.
%  Outputs:
%      out_score: the refined score by TLift, with the same size as the in_score.
%  Version:
%      1.01, 16-12-2019
%  Author:
%      Shengcai Liao
%      scliao@ieee.org
%  Reference:
%      Shengcai Liao and Ling Shao, "Interpretable and Generalizable Person Re-Identification with Query-Adaptive
%      Convolution and Temporal Lifting." In The European Conference on Computer Vision (ECCV), 23-28 August, 2020.


num_gals = length(gal_time);
num_probs = length(prob_time);
out_score = zeros(num_gals, num_probs);

prob_time_diff = prob_time - prob_time';
cooccur_mask = (abs(prob_time_diff) < tau);
g_sam_index = cell(num_cams, 1);
score = cell(num_cams, 1);
gal_time_diff = cell(num_cams, 1);

for g_cam = 1 : num_cams  
    g_sam_index{g_cam} = find(gal_cam_id == g_cam);
    score{g_cam} = in_score(g_sam_index{g_cam}, :);
    frame_id = gal_time(g_sam_index{g_cam});
    gal_time_diff{g_cam} = frame_id - frame_id';
end

for p_cam = 1 : num_cams
    p_sam_index = find(prob_cam_id == p_cam);
    c_mask = cooccur_mask(p_sam_index, p_sam_index);
    np = length(p_sam_index);
    
    for g_cam = 1 : num_cams
% No need to evaluate within-camera pairs, but in some public datasets 
%  they still evaluate negative pairs in the same camera.
%        if p_cam == g_cam
%            continue;
%        end
        
        prob_score = score{g_cam}(:, p_sam_index);

        for i = 1 : np        
            cooccur_index = find(c_mask(:, i));
            cooccur_score = prob_score(:, cooccur_index);
            [r, index] = sort(cooccur_score(:), 'descend');
            thr = r(K);
            mask_in_gal = any(cooccur_score >= thr, 2);
            
            dt = gal_time_diff{g_cam}(:, mask_in_gal);
            weight = mean(exp(-dt.^2 / sigma^2), 2);
            out_score(g_sam_index{g_cam}, p_sam_index(i)) = weight;
        end
    end
end

out_score = (out_score + alpha) .* in_score;
