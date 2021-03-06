%%% test the model performance
function [] = Demo_Test_model_L0_Res_Bnorm_Adam(color_model)


  % clear; clc;
  format compact;

  if nargin == 0
    color_model = 'color';
  end

  addpath(fullfile('data','utilities'));
  addpath(fullfile('../../methods/Bilateral_Filter'));
  addpath(fullfile('../../methods/L0'));
  addpath(fullfile('../../methods/tsmoothing'));
  addpath(fullfile('../../methods/wls'));
  
  %for test
  %folderTest  = fullfile('data','Test'); %%% test dataset
  %for gen paper image
  folderPaper = fullfile('data','paper_relative');
  folderVal = fullfile(folderPaper, 'origin');
  method = 'wls';
  outDir = fullfile(folderPaper, 'result_wls_5');
  model_post = '_WLS_5';
  
  showResult  = 1;
  useGPU      = 1;
  %useGPU      = 0;
  pauseTime   = 1;

  %%model_shape is to use for the dir
  if strcmp(color_model, 'gray')
    model_dir_shape = 'model_L0_Gray_Res_Bnorm_Adam';
  else
    model_dir_shape = strcat('model_L0_Res_Bnorm_Adam');
  end

  modelDir  = fullfile('data',strcat(model_dir_shape, model_post));
  modelName   = model_dir_shape;

  epoch       = findLastEpoch(modelDir, modelName);
  %%% load Gaussian denoising model
  load(fullfile(modelDir,[modelName,'-epoch-',num2str(epoch),'.mat']));
  disp('epoch');
  net = vl_simplenn_tidy(net);
  disp('epoch12');
  net.layers = net.layers(1:end-1);
  disp('epoch');
  %%%
  net = vl_simplenn_tidy(net);

  % for i = 1:size(net.layers,2)
  %     net.layers{i}.precious = 1;
  % end
  disp('epoch1');
  %%% move to gpu
  if useGPU
      net = vl_simplenn_move(net, 'gpu') ;
  end
  disp('epoch2');
  %%% read images
  ext         =  {'*.jpg','*.png','*.bmp'};
  filePaths   =  [];
  for i = 1 : length(ext)
      filePaths = cat(1,filePaths, dir(fullfile(folderVal,ext{i})));
  end

  %%% PSNR and SSIM
  %PSNRs = zeros(1,length(filePaths));
  %SSIMs = zeros(1,length(filePaths));
  
  for i = 1:length(filePaths)
      disp(i);
      %%% read images
      %image = imread(fullfile(folderTest,filePaths(i).name));

      input = imread(fullfile(folderVal, filePaths(i).name));
      image_path = fullfile(folderVal, filePaths(i).name);
      tic;
      if strcmp(method,'wls')
        label = wls_run(image_path);
      elseif strcmp(method, 'blf')
        label = bfilter(image_path);
      else
        label = L0Smoothing(image_path);
      end
        %label = L0Smoothing(imread(fullfile(folderVal,filePaths(i).name)));
      time1 = toc;
      
      [~,nameCur,extCur] = fileparts(filePaths(i).name);
      label = im2double(label);
      input = im2single(input);
      if strcmp(color_model, 'gray') == 1 && size(input,3) == 3
          disp('gray')
          input = rgb2gray(input);
          label = rgb2gray(label);
      end
      %%% convert to GPU
      if useGPU
          input = gpuArray(input);
      end

      tic;
      res    = vl_simplenn(net,input,[],[],'conserveMemory',true,'mode','test');
      output = input - res(end).x;
      time2 = toc;
         
      %%% convert to CPU
      if useGPU
          output = gather(output);
          input  = gather(input);
      end

      %%% calculate PSNR and SSIM
      [PSNRCur, SSIMCur] = Cal_PSNRSSIM(im2uint8(label),im2uint8(output),0,0);
      if showResult
          %imshow(im2uint8(output));
          imshow(cat(2,im2uint8(label),im2uint8(input),im2uint8(output)));
          %title([filePaths(i).name,'    ',num2str(PSNRCur,'%2.2f'),'dB','    ',num2str(SSIMCur,'%2.4f')])
          %imshow(cat(2, im2uint8(input), im2uint8(output)))
          %drawnow;
          %pause(pauseTime)
          pause;
      end
      imwrite(im2uint8(output),fullfile(outDir, filePaths(i).name));
      disp([time1, time2]);
      %PSNRs(i) = PSNRCur;
      %SSIMs(i) = SSIMCur;
  end

  %disp([mean(PSNRs),mean(SSIMs)]);
  epoch
end

%% get the max epoch net
function epoch = findLastEpoch(modelDir, modelName)
  list = dir(fullfile(modelDir,[modelName, '-epoch-*.mat']));
  tokens = regexp({list.name}, [modelName, '-epoch-([\d]+).mat'], 'tokens');
  epoch = cellfun(@(x) sscanf(x{1}{1}, '%d'), tokens);
  epoch = max([epoch 0 ]);
end
