import importlib.util
import json
from pathlib import Path
import unittest

path=Path(__file__).with_name('collect_protection_state.py')
spec=importlib.util.spec_from_file_location('collector',path)
collector=importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)
PKG='test.focus.app'
TARGET=PKG+'/.Guard'

class EvidenceTests(unittest.TestCase):
    def fixtures(self):
        return {
            ('settings','--user','0','get','secure','enabled_accessibility_services'): TARGET+':other.private/.Reader',
            ('dumpsys','accessibility'): 'Bound services:{Service[label=Guard,capabilities=1]}\nEnabled services:{{'+TARGET+'}}',
            ('dumpsys','activity','services',PKG): 'ServiceRecord{abc u0 '+TARGET+'}\nisForeground=true',
            ('dumpsys','package',PKG): 'versionCode=11 minSdk=24\nversionName=0.2.7\nUser 0: installed=true stopped=false\nUser 10: stopped=true',
            ('dumpsys','activity','exit-info',PKG): 'ApplicationExitInfo #0:\ntimestamp=2026-10-15 21:21:48.475 pid=1234\nreason=13 (OTHER KILLS BY SYSTEM) subreason=0 (UNKNOWN) description=SwipeUpClean state=secret trace=private\nApplicationExitInfo #1: reason=10 (USER REQUESTED)',
            ('pidof',PKG): '5678\n',
            ('getprop','ro.build.version.release'): '16',
            ('getprop','ro.build.version.sdk'): '36',
            ('getprop','ro.build.version.incremental'): 'TEST-ROM',
        }

    def test_label_only_is_unknown_and_private_fields_are_not_exported(self):
        data=self.fixtures()
        result=collector.collect(data.get,PKG,'.Guard')
        self.assertTrue(result['accessibility']['enabled'])
        self.assertIsNone(result['accessibility']['boundComponentVisible'])
        self.assertFalse(result['packageStopped'])
        self.assertEqual(result['latestExit']['reasonCode'],13)
        self.assertTrue(result['latestExit']['swipeUpCleanMentioned'])
        out=json.dumps(result)
        for private in ['other.private','secret','private trace','1234','5678']:
            self.assertNotIn(private,out)

    def test_exact_component_binding_and_force_stop_are_separate(self):
        data=self.fixtures()
        data[('dumpsys','accessibility')]='Bound services:{{'+TARGET+'}}'
        data[('dumpsys','package',PKG)]='versionCode=11\nversionName=0.2.7\nUser 0: stopped=true'
        data[('dumpsys','activity','exit-info',PKG)]='ApplicationExitInfo #0:\ntimestamp=2026-10-15 21:21:00.829 pid=999\nreason=10 (USER REQUESTED) subreason=21 (FORCE STOP) description=SwipeUpClean'
        result=collector.collect(data.get,PKG,TARGET)
        self.assertTrue(result['accessibility']['boundComponentVisible'])
        self.assertTrue(result['packageStopped'])
        self.assertEqual(result['latestExit']['subreason'],'FORCE STOP')

    def test_failures_and_unfamiliar_formats_stay_unknown(self):
        data=self.fixtures()
        data[('dumpsys','accessibility')]=None
        data[('dumpsys','package',PKG)]='Unrecognized format'
        data[('dumpsys','activity','services',PKG)]='Unrecognized format'
        result=collector.collect(data.get,PKG,'.Guard')
        self.assertIn('accessibility-dump',result['errors'])
        self.assertIsNone(result['packageStopped'])
        self.assertIsNone(result['versionCode'])
        self.assertIsNone(result['foregroundService'])
        self.assertIn('own-services-format',result['errors'])

    def test_enabled_null_means_disabled_but_failed_read_means_unknown(self):
        data=self.fixtures()
        key=('settings','--user','0','get','secure','enabled_accessibility_services')
        data[key]='null'
        self.assertFalse(collector.collect(data.get,PKG,'.Guard')['accessibility']['enabled'])
        data[key]='Unexpected output'
        self.assertIsNone(collector.collect(data.get,PKG,'.Guard')['accessibility']['enabled'])
        data[key]=None
        self.assertIsNone(collector.collect(data.get,PKG,'.Guard')['accessibility']['enabled'])

    def test_package_scope_is_enforced_and_commands_are_read_only(self):
        with self.assertRaises(ValueError): collector.collect(self.fixtures().get,PKG,'other.app/.Guard')
        calls=[]
        data=self.fixtures()
        def read(args):
            calls.append(args)
            return data.get(args)
        collector.collect(read,PKG,'.Guard')
        self.assertEqual(len(calls),9)
        self.assertTrue(all(args[0] in {'settings','dumpsys','pidof','getprop'} for args in calls))
        self.assertEqual(next(x for x in calls if x[0]=='settings')[3],'get')

if __name__=='__main__': unittest.main()
