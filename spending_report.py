#!/usr/bin/env python3
# illustrating function usage


def totalExpenses():
    exp1 = 1.11
    exp2 = 2.22
    exp3 = 3.33
    return exp1 + exp2 + exp3


def totalBills():
    bill1 = 4.44
    bill2 = 5.55
    bill3 = 6.66
    return bill1 + bill2 + bill3


rent = 1500
expenses = totalExpenses()
bills = totalBills()

print("\n""Rent is: " + str('${:,.2f}'.format(rent)))
print("\n""Expenses are: " + str('${:,.2f}'.format(expenses)))
print("\n""Bills are: " + str('${:,.2f}'.format(bills)))
print("\n""Total is: " + str('${:,.2f}'.format(rent + expenses + bills)))
