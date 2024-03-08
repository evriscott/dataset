% FUNCTIONAL TEST: smoke
%
% Simple tests to run on github 

function tests = testSmoke
    tests = functiontests(localfunctions);
end

function testCreate(testCase)
  a = dataset;
  testCase.assertTrue(isa(a,'dataset'))
end

function testCreateDataOnly(testCase)
% Create a dataset with data.
  didfail = 0;
  try
    a = dataset(rand(3));
  catch
    didfail = 1;
  end
  
  assert(didfail~=1,'DATASET empty dataset fail to create data only.')
end

function testSimpleMetaData(testCase)
% Create a dataset with data.
didfail = 0;
try
  a = dataset(rand(3));
  a.label{2} = {'a' 'b' 'c'};
  a.name = 'dfsdsf';
  a.axisscale{1,2} = [1 2 3];
  a.class{1,2} = [1 2 3];
catch
  didfail = 1;
end

assert(didfail~=1,'DATASET empty dataset fail to create simple data only.')
end

function testSimpleCat(testCase)
% Cat with just data.
  didfail = 0;
  try
    a = dataset(rand(3,4));
    b = dataset(rand(3,4));
    c = cat(1,a, b);
    d = [a;b];

  catch
    didfail = 1;
  end
  
  assert(didfail~=1,'DATASET simple cat fail.')
end