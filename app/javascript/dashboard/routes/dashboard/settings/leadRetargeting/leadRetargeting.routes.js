import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import LeadRetargetingIndex from './Index.vue';
import LeadRetargetingForm from './Form.vue';
import LeadRetargetingShow from './Show.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/lead-retargeting'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'lead_retargeting_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'lead_retargeting_list',
          component: LeadRetargetingIndex,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: 'new',
          name: 'lead_retargeting_new',
          component: LeadRetargetingForm,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: ':sequenceId/edit',
          name: 'lead_retargeting_edit',
          component: LeadRetargetingForm,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: ':sequenceId/show',
          name: 'lead_retargeting_show',
          component: LeadRetargetingShow,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
