import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masar_app/src/features/subscription/domain/subscription_logic.dart';

void main() {
  test('Subscription Logic Feature Flagging Test', () {
    final container = ProviderContainer();

    // 1. Initial State (No Plan)
    expect(
      container.read(featureAccessProvider(AppFeature.smartSchedule)), 
      false,
      reason: 'Should be false when no plan selected'
    );

    // 2. Select Starter Plan
    container.read(currentPlanProvider.notifier).state = SubscriptionPlanType.starter;
    
    expect(
      container.read(featureAccessProvider(AppFeature.basicBehavior)), 
      true,
      reason: 'Starter plan should have basic behavior'
    );
    expect(
      container.read(featureAccessProvider(AppFeature.smartSchedule)), 
      false,
      reason: 'Starter plan should NOT have smart schedule'
    );

    // 3. Upgrade to Elite Plan
    container.read(currentPlanProvider.notifier).state = SubscriptionPlanType.elite;

    expect(
      container.read(featureAccessProvider(AppFeature.smartSchedule)), 
      true,
      reason: 'Elite plan should have smart schedule'
    );
    
    expect(
      container.read(featureAccessProvider(AppFeature.parentAccess)), 
      true,
      reason: 'Elite plan should have parent access'
    );
  });
}
