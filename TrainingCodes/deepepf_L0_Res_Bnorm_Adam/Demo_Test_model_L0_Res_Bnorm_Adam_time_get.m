%%% test the model performance
function [] = Demo_Test_model_L0_Res_Bnorm_Adam_time_get(color_model)


  % clear; clc;
  format compact;

  if nargin == 0
    color_model = 'gray';
  end

  addpath(fullfile('data','utilities'));
  addpath(fullfile('../../methods/Bilateral_Filter'));
  addpath(fullfile('../../methods/L0'));
  addpath(fullfile('../../methods/tsmoothing'));
  addpath(fullfile('../../methods/wls'));
  
  %for test
  %folderTest  = fullfile('data','Test'); %%% test dataset
  %for gen paper image
  %folderPaper = fullfile('data','paper_relative');
  %folderVal = fullfile(folderPaper, 'origin');

  %for gen time info
  method_arr = {'l0', 'wls', 'blf'};
  method = char(method_arr(3)); %cell to str
  dataset1 = 'qvga';

  folderPaper = fullfile('data', 'time_dataset');
  folderVal = fullfile(folderPaper, dataset1);
  fp = fopen(fullfile(folderPaper, strcat('rsl_', dataset1), 'time.txt'), 'at+');
  outDir = fullfile(folderPaper, strcat('rsl_', dataset1), method);
  methods = strcat(method, '_5');

  showResult  = 1;
  %useGPU      = 1;
  useGPU      = 0;
  pauseTime   = 1;

  %%model_shape is to use for the dir
  if strcmp(color_model, 'gray')
    model_dir_shape = 'model_L0_Gray_Res_Bnorm_Adam';
  else
    model_dir_shape = 'model_L0_Res_Bnorm_Adam';
  end

  modelDir  = fullfile('data',model_dir_shape);
  modelName   = model_dir_shape;

  epoch       = findLastEpoch(modelDir, modelName);
  epoch
  %%% load Gaussian denoising model
  load(fullfile(modelDir,[modelName,'-epoch-',num2str(epoch),'.mat']));
  net = vl_simplenn_tidy(net);
  net.layers = net.layers(1:end-1);

  %%%
  net = vl_simplenn_tidy(net);

  % for i = 1:size(net.layers,2)
  %     net.layers{i}.precious = 1;
  % end

  %%% move to gpu
  if useGPU
      net = vl_simplenn_move(net, 'gpu') ;
  end

  %%% read images
  ext         =  {'*.jpg','*.png','*.bmp'};
  filePaths   =  [];
  for i = 1 : length(ext)
      filePaths = cat(1,filePaths, dir(fullfile(folderVal,ext{i})));
  end

  %%% PSNR and SSIM
  %PSNRs = zeros(1,length(filePaths));
  %SSIMs = zeros(1,length(filePaths));
  
  blanks = [32,32,32,32,32,32,32,32,32,32];
  msg = methods;
  fprintf(fp, '%s\n', msg);
  msg = 'origin          ours';
  fprintf(fp, '%s\n', msg);
  %fprintf(fp, '\r\s');
  t1 = 0;
  t2 = 0;
  for i = 1:length(filePaths)

      %%% read images
      %image = imread(fullfile(folderTest,filePaths(i).name));

      input = imread(fullfile(folderVal, filePaths(i).name));
      image_path = fullfile(folderVal, filePaths(i).name);
      tic;
      if strcmp(methods,'wls_5')
        label = wls_run(image_path);
      elseif strcmp(methods, 'blf_5')
        label = bfilter(image_path);
      else
        label = L0Smoothing(image_path);
      end
        %label = L0Smoothing(imread(fullfile(folderVal,filePaths(i).name)));
      time1 = toc;
      t1 = t1 + time1;
      
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
      t2 = t2 + time2;
      
      msg = strcat(num2str(time1), blanks, num2str(time2));
      fprintf(fp, '%s\n', msg);
      
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
  
  num = length(filePaths);
  t1 = t1 / num;
  t2 = t2 / num;
  disp([t1, t2]);
  msg = 'average';
  fprintf(fp, '%s\n', msg);
  msg = strcat(num2str(t1), blanks, num2str(t2));
  fprintf(fp, '%s\n', msg);
  msg = '';
  fprintf(fp, '%s\n\n\n', msg);
  fclose(fp);
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
