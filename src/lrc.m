function varargout = lrc(varargin)
% LRC MATLAB code for lrc.fig
%      LRC, by itself, creates a new LRC or raises the existing
%      singleton*.
%
%      H = LRC returns the handle to a new LRC or the handle to
%      the existing singleton*.
%
%      LRC('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in LRC.M with the given input arguments.
%
%      LRC('Property','Value',...) creates a new LRC or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before lrc_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to lrc_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help lrc

% Last Modified by GUIDE v2.5 30-May-2016 19:41:30

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @lrc_OpeningFcn, ...
                   'gui_OutputFcn',  @lrc_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before lrc is made visible.
function lrc_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to lrc (see VARARGIN)

% Choose default command line output for lrc
handles.output = hObject;

% Initialise default parameters
handles.kSubsampleSize = [10 5];
handles.numImages = 10;
handles.numTraining = 5;
handles.numTest = handles.numImages - handles.numTraining;
%handles.datasetFolder = '../images';
handles.datasetFolder = uigetdir();
handles.exit = false;

% Exit cleanly if no folder chosen
if isequal(handles.datasetFolder, 0)
    handles.exit = true;
    guidata(hObject, handles);
    return
end

[trainingFile, training, testFile, test, classes] = readImages(hObject, handles);

% Stores the training images in columnised format. This is the matrix X_i
% described in the paper.
handles.training = training;
handles.trainingFile = trainingFile;

% Stores the testing images.
handles.test = test;
handles.testFile = testFile;

% Names of the classes (subjects).
handles.classes = classes;

hats = computeHatMatrices(hObject, handles);

% Caches the values of the matrix H_i described in the paper.
handles.hats = hats;

computeAccuracy(hObject, handles, false);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes lrc wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = lrc_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if handles.exit
    lrc_CloseRequestFcn(hObject, eventdata, handles);
    return
end

% Get default command line output from handles structure
varargout{1} = handles.output;

computeAccuracy(hObject, handles, true);


% --- Executes when user attemps to close lrc.
function lrc_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
delete(hObject);


function [trainingFile, training, testFile, test, classes] = readImages(hObject, handles)
    % Each directory in the image directory is a subject (class).
    classes = dir(handles.datasetFolder);
    isdir = [classes.isdir];
    classes = {classes(isdir).name};
    classes(ismember(classes, {'.', '..'})) = [];

    colLen = prod(handles.kSubsampleSize);

    % Preallocate space for all training/test class images.
    training = zeros(colLen, handles.numTraining, length(classes));
    trainingFile = repmat({''}, handles.numTraining, length(classes));
    test = zeros(colLen, handles.numTest, length(classes));
    testFile = repmat({''}, handles.numTest, length(classes));

    for i = 1 : length(classes)
        imageFolder = strcat(handles.datasetFolder, '/', classes{i});
        images = [dir(strcat(imageFolder, '/', '*.pgm')); dir(strcat(imageFolder, '/', '*.jpg'))];
        isdir = [images.isdir];
        images = {images(~isdir).name};
        p = 1;
        for j = randperm(handles.numImages)
            imageFile = strcat(imageFolder, '/', images{j});

            % Read in and preprocess the image.
            img = preprocessImage(hObject, handles, imread(imageFile));

            % Store each image as a column.
            if p <= handles.numTraining
                training(:, p, i) = img;
                trainingFile{p, i} = imageFile;
            else
                test(:, p - handles.numTraining, i) = img;
                testFile{p - handles.numTraining, i} = imageFile;
            end
            p = p + 1;
        end
    end


function img = preprocessImage(hObject, handles, img)
    % Convert image to greyscale if necessary.
    if ndims(img) == 3
        img = rgb2gray(img);
    end

    % Resize image to the subsample size (defined as 10x5 in the paper).
    img = imresize(img, handles.kSubsampleSize);

    % Columnise and convert to doubles.
    colLen = prod(handles.kSubsampleSize);
    img = double(reshape(img, colLen, 1));

    % Normalise so the maximum component is 1.
    img = img / max(img);


function hats = computeHatMatrices(hObject, handles)
    % Compute H_i = X_i * (tranpose(X_i) * X_i) ^-1 * transpose(X_i)
    imageLen = prod(handles.kSubsampleSize);
    numClasses = length(handles.classes);
    hats = zeros(imageLen, imageLen, numClasses);
    for i = 1 : numClasses
           Xi = handles.training(:,:,i);
           hats(:,:,i) = Xi / (Xi' * Xi) * Xi';
    end


function [minDist, predicted] = classifyImage(hObject, handles, img)
    % For each class, compute the projection into its subspace and get
    % the one with the smallest Euclidean distance to the input image.
    dists = zeros(length(handles.classes), 1);
    for i = 1 : length(dists)
        dists(i) = sum((img - handles.hats(:,:,i) * img) .^ 2);
    end

    % Return the index of the minimum distance.
    [minDist, predicted] = min(dists);


function accuracy = computeAccuracy(hObject, handles, showProgress)
    numCorrect = 0;
    numTotal = handles.numTest * length(handles.classes);

    for i = 1 : length(handles.classes)
        for j = 1 : handles.numTest
            % Display the original class.
            if showProgress
                axes(handles.axesLeft);
                imshow(imread(handles.testFile{j, i}));
                set(handles.textOrigClass, 'String', handles.classes{i});
            end

            [minDist, predicted] = classifyImage(hObject, handles, handles.test(:, j, i));

            % Display the predicted class and distance.
            if showProgress
                axes(handles.axesRight);
                imshow(imread(handles.trainingFile{1, predicted}));
                set(handles.textPredClass, 'String', handles.classes{predicted});
                set(handles.textDist, 'String', sprintf('%.6f', minDist));
                if i == predicted
                    pause(0.5);
                else
                    pause(1.5);
                end
            end

            if predicted == i
                numCorrect = numCorrect + 1;
            end
        end
    end

    % Display the overall recognition accuracy.
    accuracy = numCorrect * 100.0 / numTotal;
    set(handles.labelAcc, 'String', sprintf('%.2f%% (%d/%d)', accuracy, numCorrect, numTotal));


% --- Executes on slider movement.
function sliderTraining_Callback(hObject, eventdata, handles)
% hObject    handle to sliderTraining (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles.numTraining = round(get(hObject, 'Value'));
set(hObject, 'Value', handles.numTraining);
handles.numTest = handles.numImages - handles.numTraining;
set(handles.labelTraining, 'String', sprintf('%d/%d', handles.numTraining, handles.numImages));
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function sliderTraining_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sliderTraining (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in buttonRun.
function buttonRun_Callback(hObject, eventdata, handles)
% hObject    handle to buttonRun (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[trainingFile, training, testFile, test, classes] = readImages(hObject, handles);
handles.training = training;
handles.trainingFile = trainingFile;
handles.test = test;
handles.testFile = testFile;
handles.classes = classes;

hats = computeHatMatrices(hObject, handles);
handles.hats = hats;

computeAccuracy(hObject, handles, false);
computeAccuracy(hObject, handles, true);

guidata(hObject, handles);
