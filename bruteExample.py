#!/usr/bin/python3
# June 6, 2021 J.A. Waters
# General brute forcing testing
# This program is provided under the MIT License

import hashlib, keyboard, math, random, string, sys, time
from multiprocessing import Pool
from itertools import permutations, product
from os import system, name
from pathlib import Path

import pkg_resources

# Set an object with required non-standard packages
required = {'inputimeout'}
# Get the currently installed packages
installed = {pkg.key for pkg in pkg_resources.working_set}
# Set the date for missing packages
missing = required - installed

# If there are any items missing, install those modules with pip
if missing:
	# Use the system python executable to run pip rather than using the pip module directly imported
	python = sys.executable
	subprocess.check_call([python, '-m', 'pip', 'install', *missing], stdout=subprocess.DEVNULL)
	
# Use the libraries for user interaction after they've been checked for installation
from inputimeout import inputimeout, TimeoutOccurred

# Program options
sys.setrecursionlimit(10**6)

runProgram = True
loggingIn = True
cracking = False
createNew = True
lastMessage = ""
pool = None
inRes = None
lenStep = 0

# Clearscreen functions
def cls():
  if name == 'nt':
    _ = system('cls')
  else:
    _ = system('clear')

def doCrack(ucheck, passhash, curStep):
  passwordFound = None
    
  # First step, check the wordlist
  if curStep == 0:
    passList = getPasswords()
    for i in range(len(passList)):
      pcheck = hashlib.sha256(bytes(str(passList[i]), "utf-8")).hexdigest()
      if passhash == pcheck:
        passwordFound = passList[i]
        break
  # Nth step, generate words from apple pie
  else:
    symList = string.ascii_letters + string.digits + string.punctuation
    passwordFound = hashCheckPerm(symList, curStep, passhash)
    
  curStep = curStep + 1
  return {"ucheck": ucheck, "passhash": passhash, "step": curStep, "found": passwordFound}

def getLogins():
  loginList = []

  if Path('logins.txt').exists():
    with open("logins.txt", "r") as reader:
      line = reader.readline()
      while len(line) > 0:
        splitLine = line.split(':')
        oName = splitLine[0].replace("\n", "")
        oPass = splitLine[1].replace("\n", "")
        loginList.insert(len(loginList), [oName, oPass])
      
        line = reader.readline() 
  
  return loginList
  
def getPasswords():
  passList = []

  if Path('password.lst').exists():
    with open("password.lst", "r") as reader:
      line = reader.readline()
      while len(line) > 0:
        newLine = line.replace("\n", "")
        passList.insert(len(passList), newLine)
      
        line = reader.readline()
        
  return passList

def hashCheckPerm(chars, nlen, passhash):
  result = None
  
  for cstr in (''.join(i) for i in product(chars, repeat = nlen)):
    pcheck = hashlib.sha256(bytes(str(cstr), "utf-8")).hexdigest()
    if pcheck == passhash:
      result = cstr
      break
  
  return result

# Entry point
if __name__ == '__main__':
  # Clear screen to begin output and allocate process pool
  cls()
  pool = Pool(processes = 3)

  while runProgram:
    print(lastMessage)
    
    if not cracking:
      print("Hello, welcome to your command environment. Please login or create a new account.\n")

    lastMessage = ""

    try:
      # Use the timeout input to wait for 3 seconds for a command, then allow loop to refresh status messages
      response = inputimeout(prompt = "1: Login\n2: New User\n3: Crack Password\n4: Quit\n", timeout = 3)
    except TimeoutOccurred:
      # Clear the last key, just in case
      response = None
    
    if response == '1':
      loggingIn = True
      while loggingIn:
        cls()
        print(lastMessage)
        response = input("Username: ")
        
        if len(response) < 2:
          lastMessage = "<<ERROR>> Please input a full username.\n"
        else:
          ucheck = response
          response = input("Password: ")
          print("\n")
          
          logonCheck = getLogins()
          
          userCorrect = False
          pcheck = hashlib.sha256(bytes(response, "utf-8")).hexdigest()
          for i in range(len(logonCheck)):
            if logonCheck[i][0] == ucheck and logonCheck[i][1] == pcheck:
              userCorrect = True
          if userCorrect:
            input("That login worked! Press 'Enter' to return to the main menu.")
            loggingIn = False
          else:
            lastMessage = "<<ERROR>> Incorrect username or password.\n"
    if response == '2':
      createNew = True
      while createNew:
        cls()
        newUser = input("New Username: ")
        
        if len(newUser) < 2:
          lastMessage = "<<ERROR>> Please input a username that is longer than 1 character."
        else:
          newPass = input("New Password: ")
          newPass = hashlib.sha256(bytes(newPass, "utf-8")).hexdigest()
          print("\n")
          
          loginList = []
          
          if len(newPass) < 4:
            lastMessage = "<<ERROR>> Passwords must be at least 4 characters long."
          else:
            loginList = getLogins()            
                
          loginList.insert(len(loginList), [newUser, newPass])

          file = open("logins.txt","w")
                    
          for i in range(len(loginList)):
            newString = loginList[i][0] + ":" + loginList[i][1]
            if i < len(loginList) - 1:
               newString += "\n"
               
            file.write(newString)
          
          file.close()
            
          lastMessage = "Your new account is created. Please login.\n"
          createNew = False
    if response == '3':
      if not cracking:      
        ucheck = input("Enter the username you want to crack: ")
        passhash = ""

        if len(ucheck) < 2:
          lastMessage = "<<ERROR>> Please input a username that is longer than 1 character."
        else:
          # Check if user is in userlist
          userExists = False
          uList = getLogins()
          for item in uList:
            if item[0] == ucheck:
              userExists = True
              passhash = item[1]

          if userExists:
            cracking = True
          else:
            input("That user is not in the database. Press 'Enter' to continue.")
      
          # Pool to be used when performing async bruteforcing
          inRes = pool.apply_async(doCrack, (ucheck, passhash, lenStep))
      else:
        newRes = input("Currently attempting to crack a password. Stop now? [Y/N]")
        if newRes.lower() == "y":
          cracking = False
          lenStep = 0
        
    if response == '4' or response == "q" or response == "Q":
      runProgram = False
      
    if cracking:
      # Whenever the doCrack process finishes, display the results
      if lenStep == 0:
        nOutput = "Checking wordlist..."
      else:
        nOutput = "Iteration %s..." % (str(lenStep))
      if inRes.ready():
        # Set the global output variable to whatever the client received
        nRes = inRes.get()
        lenStep = nRes["step"]
        ucheck = str(nRes["ucheck"])
        passhash = str(nRes["passhash"])
        
        # If password not found, start the next iteration of the async password finding task
        if nRes["found"] == None:
          inRes = pool.apply_async(doCrack, (ucheck, passhash, lenStep))
        else:
          lastMessage = ""
          lenStep = 0
          input("Password found: username '" + ucheck + "' has the password '" + nRes["found"] + "' -- Press 'Enter' to continue.")
          cracking = False
      
      if cracking:
        lastMessage = "Attempting background processing to find password for user %s: %s\n" % (ucheck, nOutput)

    cls()
