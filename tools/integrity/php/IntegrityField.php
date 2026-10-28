<?php
/**
 * Form field that shows the shipped-file integrity check on a settings page.
 *
 * Copied in from Joomla-Brain tools/integrity by Install-IntegrityCheck.ps1.
 * Change it in Joomla-Brain and re-run that script; don't edit this copy.
 *
 * @copyright   Copyright (C) 2026 Cybersalt Consulting Ltd.
 * @license     GNU General Public License version 2 or later; see LICENSE.txt
 */

declare(strict_types=1);

namespace __INTEGRITY_NAMESPACE__;

\defined('_JEXEC') or die;

use Joomla\CMS\Form\FormField;
use Joomla\CMS\Language\Text;

/**
 * For extensions with no dashboard (plugins, modules, templates):
 *
 *   <fieldset name="basic" addfieldprefix="Vendor\Plugin\System\Example\Field">
 *     <field name="integrity" type="Integrity" label="File check"
 *            lists="plugins/system/example/integrity.json"
 *            product="PLG_SYSTEM_EXAMPLE" />
 *
 * lists:   comma-separated integrity.json paths relative to the Joomla root.
 * product: language key (or plain text) for the extension's name.
 */
final class IntegrityField extends FormField
{
	protected $type = 'Integrity';

	protected function getInput()
	{
		$lists   = array_filter(array_map('trim', explode(',', (string) $this->element['lists'])));
		$product = Text::_((string) $this->element['product']);

		try {
			return IntegrityCheck::renderAlert(IntegrityCheck::run($lists), $product, true);
		} catch (\Throwable $e) {
			return '';
		}
	}
}
