package net.milosvasic.factory.mail.test

import net.milosvasic.factory.mail.component.installer.step.InstallationStepType

class ConditionStepFlowTest : SkipConditionStepFlowTest() {

    override fun name() = "Condition"

    override fun type() = InstallationStepType.CONDITION.type
}