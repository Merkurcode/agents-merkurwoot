import { frontendURL } from '../../../../helper/URLHelper';
import LocationsIndex from './pages/LocationsIndex.vue';
import LocationForm from './components/LocationForm.vue';

const commonMeta = {
  permissions: ['administrator'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/settings/locations'),
    name: 'locations_index',
    component: LocationsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/settings/locations/new'),
    name: 'location_new',
    component: LocationForm,
    meta: commonMeta,
  },
  {
    path: frontendURL(
      'accounts/:accountId/settings/locations/:locationId/edit'
    ),
    name: 'location_edit',
    component: LocationForm,
    props: route => ({ locationId: Number(route.params.locationId) }),
    meta: commonMeta,
  },
];
