# A palindromic number reads the same both ways. The largest palindrome made from the product of two 2-digit numbers is 9009 = 91 × 99.
# 
# Find the largest palindrome made from the product of two 3-digit numbers.


isPal = (n) -> 
  digits = [] 
  while n > 0 
    digits.push(n % 10) 
    n = Math.floor(n / 10) 
  len = digits.length 
  comps = [0..len/2].map (i) -> digits[i] == digits[len-i-1] 
  comps.reduce (a,b)-> a && b 

vals = []
vals.push(x*y) for x in [100..999] for y in [100..999]
pals = vals.filter (n) -> isPal(n)
biggest = pals.reduce (a,b) -> Math.max(a,b)
console.log biggest