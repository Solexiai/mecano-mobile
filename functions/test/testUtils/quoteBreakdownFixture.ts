export function buildQuoteBreakdownFixture(pricingVersion: string, customerTotal = 100) {
  const customerServiceFee = 5;
  const taxAmount = 5;
  const subtotal = customerTotal - customerServiceFee - taxAmount;
  return {
    pricingVersion,
    missionBaseValue: subtotal,
    handlingFeesTotal: 0,
    waitingFee: 0,
    additionalStopsFee: 0,
    surchargesTotal: 0,
    subtotal,
    customerDiscountAmount: 0,
    customerServiceFee,
    taxAmount,
    customerTotal,
  };
}
