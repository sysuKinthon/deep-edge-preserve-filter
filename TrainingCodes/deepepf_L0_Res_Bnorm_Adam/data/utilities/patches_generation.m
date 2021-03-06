function [inputs, labels, set] = patches_generation(color_model, size_input,size_label,stride,folder,mode,max_numPatches,batchSize)

%% color_model = gray for gray image
if strcmp(color_model,'gray') == 1
  PG_channel = 1;
elseif strcmp(color_model,'color') == 1
  PG_channel = 3;
end

padding = abs(size_input- size_input) / 2;

pwd
%% get all the picture path
ext          = {'*.jpg', '*.png', '*.bmp'};
filepaths    = [];
fullfile(folder)
for i = 1 : length(ext)
    filepaths = cat(1,filepaths, dir(fullfile(folder, ext{i})));
end

%% init all the data
count = 0;
inputs  = zeros(size_input, size_input, PG_channel, 1,'single');
labels  = zeros(size_label, size_label, PG_channel, 1,'single');

for i = 1 : length(filepaths)
  disp(i);
  %image = imread('test.jpg');
  %image = imread(fullfile(folder, filepaths(i).name));
  %image_label = L0Smoothing(image);
  image_path = fullfile(folder,filepaths(i).name);
  image = imread(image_path);
  %image_label = L0Smoothing(image_path);
  image_label = bfilter(image_path);
  %image_label = wls_run(image_path);
  if size(image, 3) == 3 && strcmp(color_model, 'gray') == 1
    image = rgb2gray(image); %uint8
    image_label = rgb2gray(image_label); %uint8
  end

  %%augmentation data and Generate patches
  for j = 1:8
      image_aug = data_augmentation(image, j);  % augment data
      image_label_aug  = data_augmentation(image_label, j);
      im_input = im2single(image_aug); % single
      im_label = im2single(image_label_aug);
      [hei,wid,chl] = size(im_label);
      for x = 1 : stride : (hei-size_input+1)
          for y = 1 :stride : (wid-size_input+1)
              subim_input = im_input(x : x+size_input-1, y : y+size_input-1,:);
              subim_label = im_label(x+padding : x+padding+size_label-1, y+padding : y+padding+size_label-1,:);
              count       = count+1;
              inputs(:, :, :, count) = subim_input;
              labels(:, :, :, count) = subim_label;
          end
      end
  end
end


%% go on deal with the data according with the bachSize the inputs and the lables must tobe the multiple of the batchSiz and Generate the residual
inputs = inputs(:,:,:,1:(size(inputs,4)-mod(size(inputs,4),batchSize)));
labels = labels(:,:,:,1:(size(labels ,4)-mod(size(labels ,4),batchSize)));
labels = shave(inputs,[padding,padding])-labels; %%% residual image patches; pay attention to this!!!

%shuffle the data; according the order to shuffle the train data order;
order  = randperm(size(inputs,4));
inputs = inputs(:, :, :, order);
labels = labels(:, :, :, order);

%%show some
input_one = inputs(:,:,:,5);
label_one = labels(:,:,:,5);
imshow(cat(2, im2uint8(input_one), im2uint8(label_one)));
drawnow;
pause(1);

% distinguish the train data and the test data
set    = uint8(ones(1,size(inputs,4)));
if mode == 1
    set = uint8(2*ones(1,size(inputs,4)));
end

%limitation the pathces num
disp('-------Original Datasize-------')
disp(size(inputs,4));

subNum = min(size(inputs,4),max_numPatches);
inputs = inputs(:,:,:,1:subNum);
labels = labels(:,:,:,1:subNum);
set    = set(1:subNum);

disp('-------Now Datasize-------')
disp(size(inputs,4));
